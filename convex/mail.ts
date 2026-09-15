import { internalMutation, mutation, query } from "./_generated/server";
import { internal, components } from "./_generated/api";
import { v } from "convex/values";

export const threadsByJob = query({
  args: { jobId: v.id("jobs") },
  handler: async (ctx, { jobId }) => {
    const msgs = await ctx.db
      .query("messages")
      .withIndex("by_job", (q) => q.eq("jobId", jobId))
      .order("desc")
      .take(50);

    const firmIds = [...new Set(msgs.map((m) => m.firmId).filter(Boolean))];
    const firms = await Promise.all(firmIds.map((id) => ctx.db.get(id)));
    const nameById = new Map(firms.filter(Boolean).map((f) => [f._id, f.name]));

    return msgs.map((m) => ({
      ...m,
      firmName: m.firmId ? nameById.get(m.firmId) ?? "Unknown" : "Unknown",
    }));
  },
});

export const recordOutbound = internalMutation({
  args: {
    jobId: v.id("jobs"),
    firmId: v.id("firms"),
    subject: v.string(),
    body: v.string(),
    fromAddress: v.string(),
    toAddress: v.string(),
    messageId: v.optional(v.string()),
    threadId: v.optional(v.string()),
    kind: v.string(),
  },
  handler: async (ctx, args) => {
    await ctx.db.insert("messages", {
      ...args,
      direction: "out",
      attachments: [],
      createdAt: Date.now(),
    });

    const inv = await ctx.db
      .query("invitations")
      .withIndex("by_job", (q) => q.eq("jobId", args.jobId))
      .collect();
    const mine = inv.find((i) => i.firmId === args.firmId);
    if (mine) {
      await ctx.db.patch(mine._id, {
        threadId: args.threadId,
        lastChasedAt: args.kind === "chase" ? Date.now() : mine.lastChasedAt,
        chaseCount: args.kind === "chase" ? mine.chaseCount + 1 : mine.chaseCount,
      });
    }

    const job = await ctx.db.get(args.jobId);
    const firm = await ctx.db.get(args.firmId);
    if (job) {
      await ctx.db.insert("events", {
        projectId: job.projectId,
        jobId: args.jobId,
        type: args.kind === "chase" ? "chase_sent" : "invite_sent",
        summary:
          args.kind === "chase"
            ? `Followed up with ${firm?.name ?? "a firm"} - no reply yet`
            : `Emailed ${firm?.name ?? "a firm"} asking for a price`,
        createdAt: Date.now(),
      });
    }
  },
});

// Inbound: match sender to a firm, store the message, try to read a quote.
export const handleInbound = internalMutation({
  args: {
    fromAddress: v.string(),
    toAddress: v.string(),
    subject: v.optional(v.string()),
    text: v.string(),
    messageId: v.optional(v.string()),
    threadId: v.optional(v.string()),
    attachments: v.optional(
      v.array(
        v.object({
          filename: v.string(),
          url: v.string(),
          contentType: v.optional(v.string()),
        })
      )
    ),
  },
  handler: async (ctx, args) => {
    const addr = args.fromAddress.toLowerCase().trim();
    const firm = await ctx.db
      .query("firms")
      .withIndex("by_email", (q) => q.eq("email", addr))
      .first();

    // find the job this thread belongs to
    let jobId = null;
    if (firm) {
      const invs = await ctx.db
        .query("invitations")
        .withIndex("by_firm", (q) => q.eq("firmId", firm._id))
        .collect();
      const byThread = invs.find((i) => i.threadId === args.threadId);
      jobId = (byThread ?? invs[0])?.jobId ?? null;
    }
    if (!jobId) {
      const anyJob = await ctx.db.query("jobs").first();
      jobId = anyJob?._id ?? null;
    }
    if (!jobId) return { ignored: true };

    await ctx.db.insert("messages", {
      jobId,
      firmId: firm?._id,
      direction: "in",
      subject: args.subject,
      body: args.text,
      fromAddress: addr,
      toAddress: args.toAddress,
      messageId: args.messageId,
      threadId: args.threadId,
      attachments: args.attachments ?? [],
      kind: "reply",
      createdAt: Date.now(),
    });

    const job = await ctx.db.get(jobId);
    if (job) {
      await ctx.db.insert("events", {
        projectId: job.projectId,
        jobId,
        type: "reply_received",
        summary: `Reply from ${firm?.name ?? addr}`,
        createdAt: Date.now(),
      });
    }

    if (!firm) return { stored: true, matched: false };

    // mark replied
    const invs = await ctx.db
      .query("invitations")
      .withIndex("by_firm", (q) => q.eq("firmId", firm._id))
      .collect();
    const inv = invs.find((i) => i.jobId === jobId);
    if (inv && inv.status !== "quoted") {
      await ctx.db.patch(inv._id, { status: "replied" });
    }

    // try to read a price out of the body
    const parsed = extractQuote(args.text);
    if (parsed.total == null) return { stored: true, matched: true, quoted: false };

    await ctx.runMutation(components.quoteEngine.quotes.record, {
      jobKey: String(jobId),
      partyKey: String(firm._id),
      partyName: firm.name,
      total: parsed.total,
      lineItems: parsed.lineItems,
      inclusions: parsed.inclusions,
      exclusions: parsed.exclusions,
      scopeTags: ["asphalt-shingle"],
      needsReview: parsed.needsReview,
      rawText: args.text.slice(0, 4000),
    });

    if (inv) await ctx.db.patch(inv._id, { status: "quoted" });

    await ctx.db.insert("events", {
      projectId: job.projectId,
      jobId,
      type: "quote_parsed",
      summary: `Read ${firm.name}'s price: $${parsed.total.toLocaleString()}${
        parsed.exclusions.length
          ? ` - excludes ${parsed.exclusions.join(", ")}`
          : ""
      }`,
      createdAt: Date.now() + 1,
    });

    return { stored: true, matched: true, quoted: true };
  },
});

// Heuristic reader. Firecrawl /parse will replace this for PDFs.
function extractQuote(text) {
  const clean = text.replace(/\r/g, "");
  const lineItems = [];
  const exclusions = [];
  const inclusions = [];
  let total = null;
  let needsReview = false;

  const moneyRe = /\$\s?([\d,]+(?:\.\d{2})?)/g;
  const num = (s) => Number(String(s).replace(/,/g, ""));

  // explicit total wins
  const totalLine = clean
    .split("\n")
    .find((l) => /\b(total|lump sum|all[- ]in|our price|quote)\b/i.test(l) && /\$/.test(l));
  if (totalLine) {
    const m = [...totalLine.matchAll(moneyRe)];
    if (m.length) total = num(m[m.length - 1][1]);
  }

  for (const line of clean.split("\n")) {
    const t = line.trim();
    if (!t) continue;

    if (/^(excl|excludes?|not included|we exclude)/i.test(t)) {
      t.replace(/^[^:]*:?/, "")
        .split(/[,;]/)
        .map((s) => s.trim())
        .filter(Boolean)
        .forEach((s) => exclusions.push(titleCase(s)));
      continue;
    }
    if (/^(incl|includes?|included)/i.test(t)) {
      t.replace(/^[^:]*:?/, "")
        .split(/[,;]/)
        .map((s) => s.trim())
        .filter(Boolean)
        .forEach((s) => inclusions.push(titleCase(s)));
      continue;
    }

    const m = [...t.matchAll(moneyRe)];
    if (m.length && !/\b(total|lump sum|all[- ]in)\b/i.test(t)) {
      const label = t.split("$")[0].replace(/[-:\u2013]\s*$/, "").trim();
      if (label.length > 2 && label.length < 80) {
        lineItems.push({ label: titleCase(label), amount: num(m[0][1]) });
      }
    }
  }

  if (total == null && lineItems.length) {
    total = lineItems.reduce((a, b) => a + (b.amount ?? 0), 0);
    needsReview = true;
  }
  if (total == null) {
    const all = [...clean.matchAll(moneyRe)].map((m) => num(m[1]));
    if (all.length) {
      total = Math.max(...all);
      needsReview = true;
    }
  }
  if (!exclusions.length) needsReview = true;

  return { total, lineItems, exclusions, inclusions, needsReview };
}

function titleCase(s) {
  const t = s.trim().replace(/\.$/, "");
  return t.charAt(0).toUpperCase() + t.slice(1);
}
