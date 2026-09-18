import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

// Contractors describe the same item a dozen ways. The component decides
// what counts as the same thing, so the board has one row per real item.
const CANONICAL: Array<[string, string[]]> = [
  ["Removal and disposal", ["removal", "disposal", "tear-off", "tear off", "strip"]],
  ["Delivery", ["delivery", "deliver", "transport", "haulage"]],
  ["Skip hire", ["skip", "dumpster", "waste container"]],
  ["Crane hire", ["crane", "craneage", "hoist"]],
  ["Sales tax", ["sales tax", "tax", "vat"]],
  ["Night work", ["night work", "out of hours", "overtime"]],
  ["Gutter replacement", ["gutter", "guttering", "downpipe"]],
  ["Temporary protection", ["temporary protection", "sheeting", "scaffold cover"]],
  ["Scaffolding", ["scaffold"]],
  ["Structural repair", ["structural", "rafter", "joist", "decking repair"]],
  ["Permits", ["permit", "building control", "planning"]],
  ["Warranty", ["warranty", "guarantee"]],
];

export function canonical(raw: string): string {
  const t = raw.toLowerCase();
  for (const [label, needles] of CANONICAL) {
    if (needles.some((n) => t.includes(n))) return label;
  }
  // nothing matched - keep it, but tidied
  const clean = raw.trim().replace(/\.$/, "");
  return clean.charAt(0).toUpperCase() + clean.slice(1);
}

function canonicalList(arr?: string[]): string[] {
  return [...new Set((arr ?? []).filter(Boolean).map(canonical))];
}

const lineItem = v.object({
  label: v.string(),
  amount: v.optional(v.number()),
  note: v.optional(v.string()),
});

// ---------- writing ----------

export const record = mutation({
  args: {
    jobKey: v.string(),
    partyKey: v.string(),
    partyName: v.string(),
    total: v.optional(v.number()),
    currency: v.optional(v.string()),
    lineItems: v.optional(v.array(lineItem)),
    inclusions: v.optional(v.array(v.string())),
    exclusions: v.optional(v.array(v.string())),
    scopeTags: v.optional(v.array(v.string())),
    needsReview: v.optional(v.boolean()),
    rawText: v.optional(v.string()),
    sourceUrl: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("quotes")
      .withIndex("by_job_party", (q) =>
        q.eq("jobKey", args.jobKey).eq("partyKey", args.partyKey)
      )
      .first();

    const doc = {
      jobKey: args.jobKey,
      partyKey: args.partyKey,
      partyName: args.partyName,
      total: args.total,
      currency: args.currency ?? "USD",
      lineItems: args.lineItems ?? [],
      inclusions: canonicalList(args.inclusions),
      exclusions: canonicalList(args.exclusions),
      scopeTags: args.scopeTags ?? [],
      valid: true,
      invalidReason: undefined,
      needsReview: args.needsReview ?? false,
      rawText: args.rawText,
      sourceUrl: args.sourceUrl,
      receivedAt: Date.now(),
    };

    const id = existing
      ? (await ctx.db.patch(existing._id, doc), existing._id)
      : await ctx.db.insert("quotes", doc);

    await relearnBenchmarks(ctx, args.jobKey);
    return id;
  },
});

export const confirm = mutation({
  args: {
    quoteId: v.id("quotes"),
    total: v.optional(v.number()),
    exclusions: v.optional(v.array(v.string())),
    lineItems: v.optional(v.array(lineItem)),
  },
  handler: async (ctx, { quoteId, ...patch }) => {
    const clean: any = Object.fromEntries(
      Object.entries(patch).filter(([, val]) => val !== undefined)
    );
    if (clean.exclusions) clean.exclusions = canonicalList(clean.exclusions);
    await ctx.db.patch(quoteId, { ...clean, needsReview: false });
    const q = await ctx.db.get(quoteId);
    if (q) await relearnBenchmarks(ctx, q.jobKey);
  },
});

// The job changed. A price survives only if it already covered the new scope.
export const invalidate = mutation({
  args: { jobKey: v.string(), newTag: v.string(), reason: v.string() },
  handler: async (ctx, { jobKey, newTag, reason }) => {
    const quotes = await ctx.db
      .query("quotes")
      .withIndex("by_job", (q) => q.eq("jobKey", jobKey))
      .collect();

    const invalidated = [];
    const survived = [];
    for (const q of quotes) {
      if (q.scopeTags.includes(newTag)) {
        survived.push(q.partyName);
      } else if (q.valid) {
        await ctx.db.patch(q._id, { valid: false, invalidReason: reason });
        invalidated.push(q.partyName);
      }
    }
    return { invalidated, survived };
  },
});

export const revalidateAll = mutation({
  args: { jobKey: v.string() },
  handler: async (ctx, { jobKey }) => {
    const quotes = await ctx.db
      .query("quotes")
      .withIndex("by_job", (q) => q.eq("jobKey", jobKey))
      .collect();
    let n = 0;
    for (const q of quotes) {
      if (!q.valid) {
        await ctx.db.patch(q._id, { valid: true, invalidReason: undefined });
        n++;
      }
    }
    return { restored: n };
  },
});

export const clearJob = mutation({
  args: { jobKey: v.string() },
  handler: async (ctx, { jobKey }) => {
    const quotes = await ctx.db
      .query("quotes")
      .withIndex("by_job", (q) => q.eq("jobKey", jobKey))
      .collect();
    for (const q of quotes) await ctx.db.delete(q._id);
    const bms = await ctx.db.query("benchmarks").collect();
    for (const b of bms) if (b.jobKey === jobKey) await ctx.db.delete(b._id);
    return { deleted: quotes.length };
  },
});

export const clearAll = mutation({
  args: {},
  handler: async (ctx) => {
    for (const t of ["quotes", "benchmarks"]) {
      const rows = await ctx.db.query(t).collect();
      for (const r of rows) await ctx.db.delete(r._id);
    }
    return { cleared: true };
  },
});

// ---------- reading ----------

// The whole comparison, computed here rather than in the UI. This is the
// component's reason to exist: the host asks "who is actually cheapest"
// and gets an answer that accounts for what each price leaves out.
export const compare = query({
  args: { jobKey: v.string() },
  handler: async (ctx, { jobKey }) => {
    const quotes = await ctx.db
      .query("quotes")
      .withIndex("by_job", (q) => q.eq("jobKey", jobKey))
      .collect();

    const benchmarks = (await ctx.db.query("benchmarks").collect()).filter(
      (b) => b.jobKey === jobKey
    );
    const priceOf = new Map(benchmarks.map((b) => [b.label, b.amount]));

    const allExclusions = [
      ...new Set(quotes.flatMap((q) => q.exclusions)),
    ].sort();

    const rows = quotes.map((q) => {
      // add back the going rate for everything this price excludes
      const gaps = q.exclusions
        .map((label) => ({ label, amount: priceOf.get(label) ?? null }))
        .filter((g) => g.amount != null);
      const hidden = gaps.reduce((a, g) => a + (g.amount ?? 0), 0);
      const comparable = q.total != null ? q.total + hidden : null;

      return {
        quoteId: q._id,
        partyKey: q.partyKey,
        partyName: q.partyName,
        total: q.total,
        comparable,
        hidden,
        gaps,
        currency: q.currency,
        lineItems: q.lineItems,
        inclusions: q.inclusions,
        exclusions: q.exclusions,
        scopeTags: q.scopeTags,
        valid: q.valid,
        invalidReason: q.invalidReason,
        needsReview: q.needsReview,
        receivedAt: q.receivedAt,
      };
    });

    const live = rows.filter((r) => r.valid && r.comparable != null);
    const byHeadline = rows.filter((r) => r.valid && r.total != null);

    const cheapestComparable = live.length
      ? live.reduce((a, b) => (b.comparable < a.comparable ? b : a))
      : null;
    const cheapestHeadline = byHeadline.length
      ? byHeadline.reduce((a, b) => (b.total < a.total ? b : a))
      : null;

    // before anything was invalidated
    const allPriced = rows.filter((r) => r.comparable != null);
    const previousBest = allPriced.length
      ? allPriced.reduce((a, b) => (b.comparable < a.comparable ? b : a))
      : null;

    return {
      rows,
      allExclusions,
      benchmarks,
      cheapestComparable,
      cheapestHeadline,
      previousBest,
      // the headline price is a trap when these differ
      headlineMisleads:
        !!cheapestComparable &&
        !!cheapestHeadline &&
        cheapestComparable.partyKey !== cheapestHeadline.partyKey,
      bestMoved:
        !!cheapestComparable &&
        !!previousBest &&
        cheapestComparable.partyKey !== previousBest.partyKey,
      validCount: live.length,
      invalidCount: rows.filter((r) => !r.valid).length,
      quotedCount: rows.length,
    };
  },
});

export const listByJob = query({
  args: { jobKey: v.string() },
  handler: async (ctx, { jobKey }) =>
    ctx.db
      .query("quotes")
      .withIndex("by_job", (q) => q.eq("jobKey", jobKey))
      .collect(),
});

// ---------- internal ----------

// Learn what each excluded item costs from the quotes that did price it.
async function relearnBenchmarks(ctx, jobKey) {
  const quotes = await ctx.db
    .query("quotes")
    .withIndex("by_job", (q) => q.eq("jobKey", jobKey))
    .collect();

  const totals = new Map();
  for (const q of quotes) {
    for (const item of q.lineItems) {
      if (item.amount == null) continue;
      for (const label of q.inclusions) {
        if (!matches(item.label, label) && canonical(item.label) !== label)
          continue;
        const cur = totals.get(label) ?? { sum: 0, n: 0 };
        cur.sum += item.amount;
        cur.n += 1;
        totals.set(label, cur);
      }
    }
  }

  for (const [label, { sum, n }] of totals) {
    const amount = Math.round(sum / n);
    const existing = await ctx.db
      .query("benchmarks")
      .withIndex("by_job_label", (q) =>
        q.eq("jobKey", jobKey).eq("label", label)
      )
      .first();
    if (existing) {
      await ctx.db.patch(existing._id, { amount, samples: n });
    } else {
      await ctx.db.insert("benchmarks", { jobKey, label, amount, samples: n });
    }
  }
}

function matches(lineLabel, exclusionLabel) {
  const a = lineLabel.toLowerCase();
  const b = exclusionLabel.toLowerCase();
  if (a.includes(b) || b.includes(a)) return true;
  const words = b.split(/\s+/).filter((w) => w.length > 3);
  return words.some((w) => a.includes(w));
}
