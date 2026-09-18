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
      await ctx.runMutation(internal.readerNotes.noteDecline, {
        jobId,
        firmId,
        firmName,
      });
      return { declined: true };
    }

    if (typeof parsed.total !== "number") {
      await ctx.runMutation(internal.readerNotes.noteUnclear, {
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

    await ctx.runMutation(internal.readerNotes.noteRead, {
      jobId,
      firmId,
      firmName,
      total: parsed.total,
      exclusions: clean(parsed.exclusions),
    });

    return { total: parsed.total, exclusions: clean(parsed.exclusions) };
  },
});
