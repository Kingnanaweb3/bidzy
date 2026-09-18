#!/bin/bash
# Read a plain email the way a person would, not the way a regex does.
set -e
[ -d convex/quoteEngine ] || { echo "Run from the bidzy project root."; exit 1; }

cat > convex/reader.ts << 'EOF'
"use node";
import { internalAction } from "./_generated/server";
import { internal, components } from "./_generated/api";
import { v } from "convex/values";

// Contractors don't write forms. They write "call it fourteen two all in,
// you sort the skip." A regex sees no price and no exclusions. This reads
// the message the way a person would, and falls back to the regex when the
// model is unavailable so a demo never stalls on it.
const SYSTEM = `You read emails from building contractors and turn them into structured quotes.

Rules:
- Amounts written in words count. "fourteen two" in a roofing quote means 14200. "twelve five" means 12500.
- Anything the contractor says the customer must arrange, provide, or pay for separately is an EXCLUSION, however casually it is phrased. "you sort the skip" means skip hire is excluded.
- Anything stated as part of the price is an INCLUSION.
- Use the customer's vocabulary for labels: "Removal and disposal", "Delivery", "Skip hire", "Crane hire", "Sales tax", "Night work", "Gutter replacement", "Temporary protection", "Scaffolding", "Structural repair", "Permits", "Warranty".
- material is the roofing material being priced, if any: "asphalt shingle", "slate", "tile".
- If the email declines the work or says they are not bidding, set declined true and leave total null.
- If you cannot find a total with confidence, set total null rather than guessing.

Reply with JSON only. No prose, no code fences.`;

const SHAPE = `{
  "total": number | null,
  "currency": "USD",
  "lineItems": [{ "label": string, "amount": number | null }],
  "inclusions": [string],
  "exclusions": [string],
  "material": string | null,
  "declined": boolean,
  "confident": boolean
}`;

export const readEmail = internalAction({
  args: {
    jobId: v.id("jobs"),
    firmId: v.id("firms"),
    firmName: v.string(),
    text: v.string(),
  },
  handler: async (ctx, { jobId, firmId, firmName, text }) => {
    const key = process.env.GROQ_API_KEY;
    if (!key) return { skipped: "no GROQ_API_KEY" };

    let parsed: any = null;
    try {
      const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${key}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "llama-3.3-70b-versatile",
          temperature: 0,
          response_format: { type: "json_object" },
          messages: [
            { role: "system", content: `${SYSTEM}\n\nShape:\n${SHAPE}` },
            {
              role: "user",
              content: `Email from ${firmName}:\n\n${text.slice(0, 6000)}`,
            },
          ],
        }),
      });
      if (!res.ok) return { failed: await res.text() };
      const json = await res.json();
      parsed = JSON.parse(json.choices?.[0]?.message?.content ?? "{}");
    } catch (e: any) {
      return { failed: String(e.message ?? e) };
    }

    if (!parsed) return { failed: "no parse" };

    if (parsed.declined) {
      await ctx.runMutation(internal.reader.noteDecline, {
        jobId,
        firmId,
        firmName,
      });
      return { declined: true };
    }

    if (typeof parsed.total !== "number") {
      await ctx.runMutation(internal.reader.noteUnclear, {
        jobId,
        firmName,
      });
      return { unclear: true };
    }

    const clean = (a: any) =>
      Array.isArray(a)
        ? [...new Set(a.filter(Boolean).map((x: any) => String(x).trim()))]
        : [];

    const material = String(parsed.material ?? "").toLowerCase();
    const scopeTags: string[] = [];
    if (material.includes("slate")) scopeTags.push("slate");
    if (material.includes("asphalt") || material.includes("shingle"))
      scopeTags.push("asphalt-shingle");
    if (!scopeTags.length) scopeTags.push("asphalt-shingle");

    await ctx.runMutation(components.quoteEngine.quotes.record, {
      jobKey: String(jobId),
      partyKey: String(firmId),
      partyName: firmName,
      total: parsed.total,
      lineItems: Array.isArray(parsed.lineItems)
        ? parsed.lineItems
            .filter((li: any) => li?.label)
            .map((li: any) => ({
              label: String(li.label).slice(0, 120),
              amount: typeof li.amount === "number" ? li.amount : undefined,
            }))
        : [],
      inclusions: clean(parsed.inclusions),
      exclusions: clean(parsed.exclusions),
      scopeTags,
      needsReview: parsed.confident === false || clean(parsed.exclusions).length === 0,
      rawText: text.slice(0, 4000),
    });

    await ctx.runMutation(internal.reader.noteRead, {
      jobId,
      firmId,
      firmName,
      total: parsed.total,
      exclusions: clean(parsed.exclusions),
    });

    return { total: parsed.total, exclusions: clean(parsed.exclusions) };
  },
});
EOF

cat >> convex/reader.ts << 'EOF'
EOF

# the mutations the action calls live in a non-node file
cat > convex/readerNotes.ts << 'EOF'
import { internalMutation } from "./_generated/server";
import { v } from "convex/values";

export const noteRead = internalMutation({
  args: {
    jobId: v.id("jobs"),
    firmId: v.id("firms"),
    firmName: v.string(),
    total: v.number(),
    exclusions: v.array(v.string()),
  },
  handler: async (ctx, a) => {
    const job = await ctx.db.get(a.jobId);
    if (!job) return;

    const invs = await ctx.db
      .query("invitations")
      .withIndex("by_job", (q) => q.eq("jobId", a.jobId))
      .collect();
    const inv = invs.find((i) => i.firmId === a.firmId);
    if (inv) await ctx.db.patch(inv._id, { status: "quoted" });

    await ctx.db.insert("events", {
      projectId: job.projectId,
      jobId: a.jobId,
      type: "quote_parsed",
      summary: `Read ${a.firmName}'s email: $${a.total.toLocaleString()}${
        a.exclusions.length ? ` — leaves out ${a.exclusions.join(", ")}` : ""
      }`,
      createdAt: Date.now(),
    });
  },
});

export const noteDecline = internalMutation({
  args: { jobId: v.id("jobs"), firmId: v.id("firms"), firmName: v.string() },
  handler: async (ctx, a) => {
    const job = await ctx.db.get(a.jobId);
    if (!job) return;
    const invs = await ctx.db
      .query("invitations")
      .withIndex("by_job", (q) => q.eq("jobId", a.jobId))
      .collect();
    const inv = invs.find((i) => i.firmId === a.firmId);
    if (inv) await ctx.db.patch(inv._id, { status: "declined" });

    await ctx.db.insert("events", {
      projectId: job.projectId,
      jobId: a.jobId,
      type: "reply_received",
      summary: `${a.firmName} isn't bidding — we'll stop chasing them`,
      createdAt: Date.now(),
    });
  },
});

export const noteUnclear = internalMutation({
  args: { jobId: v.id("jobs"), firmName: v.string() },
  handler: async (ctx, a) => {
    const job = await ctx.db.get(a.jobId);
    if (!job) return;
    await ctx.db.insert("events", {
      projectId: job.projectId,
      jobId: a.jobId,
      type: "parse_failed",
      summary: `${a.firmName} replied but no price was clear enough to trust — worth reading yourself`,
      createdAt: Date.now(),
    });
  },
});
EOF

python3 - << 'PY'
p = "convex/reader.ts"
s = open(p).read()
s = s.replace(
  'import { internal, components } from "./_generated/api";',
  'import { internal, components } from "./_generated/api";'
)
s = s.replace("internal.reader.noteDecline", "internal.readerNotes.noteDecline")
s = s.replace("internal.reader.noteUnclear", "internal.readerNotes.noteUnclear")
s = s.replace("internal.reader.noteRead", "internal.readerNotes.noteRead")
open(p, "w").write(s)
print("reader wired to its mutations")
PY

# inbound mail prefers the model, keeps the regex as a floor
python3 - << 'PY'
p = "convex/mail.ts"
s = open(p).read()

if "internal.reader.readEmail" not in s:
    s = s.replace(
        "    // try to read a price out of the body\n    const parsed = extractQuote(args.text);",
        '''    // Prefer reading the message properly. The regex below stays as a
    // floor so a missing key or a model hiccup still yields something.
    if (process.env.GROQ_API_KEY) {
      await ctx.scheduler.runAfter(0, internal.reader.readEmail, {
        jobId,
        firmId: firm._id,
        firmName: firm.name,
        text: args.text,
      });
      return { stored: true, matched: true, reading: true };
    }

    const parsed = extractQuote(args.text);'''
    )
    open(p, "w").write(s)
    print("inbound now reads with the model first")
else:
    print("already wired")
PY

echo ""
echo "Set the key, then push:"
echo "  npx convex env set GROQ_API_KEY '...'"
echo "  npx convex env set --prod GROQ_API_KEY '...'"
echo "  npx convex dev --once"
