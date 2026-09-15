#!/bin/bash
# Bidzy: extract quote intelligence into a real Convex component.
# Usage:  bash bidzy-component.sh stage1
#         npx convex run legacy:clearQuotes
#         bash bidzy-component.sh stage2
set -e
[ -d convex ] || { echo "Run from the bidzy project root."; exit 1; }
STAGE="${1:-}"

if [ "$STAGE" = "stage1" ]; then
cat > convex/legacy.ts << 'EOF'
import { mutation } from "./_generated/server";

// One-off: empties the app-level quotes table so the table can be
// removed from the app schema and owned by the quoteEngine component.
export const clearQuotes = mutation({
  args: {},
  handler: async (ctx) => {
    const rows = await ctx.db.query("quotes").collect();
    for (const r of rows) await ctx.db.delete(r._id);
    return { deleted: rows.length };
  },
});
EOF
echo "stage1 written."
echo "Now run:  npx convex run legacy:clearQuotes"
echo "Then:     bash bidzy-component.sh stage2"
exit 0
fi

if [ "$STAGE" != "stage2" ]; then
  echo "Pass stage1 or stage2. See the top of this file."
  exit 1
fi

echo "Building the quoteEngine component..."
mkdir -p convex/quoteEngine

# ---------------- the component ----------------
cat > convex/quoteEngine/convex.config.ts << 'EOF'
import { defineComponent } from "convex/server";

// Quote intelligence. Owns everything about what a price actually means:
// normalisation, what it leaves out, comparable cost, and whether it is
// still valid for the job as it now stands.
//
// Tables here are isolated. Nothing in the host app can read or write them
// except through the functions this component exports.
export default defineComponent("quoteEngine");
EOF

cat > convex/quoteEngine/schema.ts << 'EOF'
import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  quotes: defineTable({
    // Opaque keys. Ids don't cross the component boundary, so the host
    // passes strings and the component never learns what a job or a
    // company actually is.
    jobKey: v.string(),
    partyKey: v.string(),
    partyName: v.string(),

    total: v.optional(v.number()),
    currency: v.string(),
    lineItems: v.array(
      v.object({
        label: v.string(),
        amount: v.optional(v.number()),
        note: v.optional(v.string()),
      })
    ),
    inclusions: v.array(v.string()),
    exclusions: v.array(v.string()),

    // which parts of the job this price depends on
    scopeTags: v.array(v.string()),

    valid: v.boolean(),
    invalidReason: v.optional(v.string()),
    needsReview: v.boolean(),

    rawText: v.optional(v.string()),
    sourceUrl: v.optional(v.string()),
    receivedAt: v.number(),
  })
    .index("by_job", ["jobKey"])
    .index("by_job_party", ["jobKey", "partyKey"]),

  // what the market says a given exclusion costs, learned from the
  // quotes that did price it
  benchmarks: defineTable({
    jobKey: v.string(),
    label: v.string(),
    amount: v.number(),
    samples: v.number(),
  }).index("by_job_label", ["jobKey", "label"]),
});
EOF

cat > convex/quoteEngine/quotes.ts << 'EOF'
import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

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
      inclusions: args.inclusions ?? [],
      exclusions: args.exclusions ?? [],
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
    const clean = Object.fromEntries(
      Object.entries(patch).filter(([, val]) => val !== undefined)
    );
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
        if (!matches(item.label, label)) continue;
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
EOF

# ---------------- register it ----------------
cat > convex/convex.config.ts << 'EOF'
import { defineApp } from "convex/server";
import staticHosting from "@convex-dev/static-hosting/convex.config";
import quoteEngine from "./quoteEngine/convex.config";

const app = defineApp();

// Serves the built frontend from this same deployment.
app.use(staticHosting);

// Owns quote normalisation, comparable cost and validity. Its tables are
// unreachable from the rest of the app - the only way in is its API.
app.use(quoteEngine);

export default app;
EOF

# ---------------- app schema: quotes table removed ----------------
python3 - << 'PY'
import re
p = "convex/schema.ts"
s = open(p).read()
start = s.index("  quotes: defineTable({")
end = s.index('.index("by_firm", ["firmId"]),', start) + len('.index("by_firm", ["firmId"]),')
s = s[:start] + "  // quotes now live in the quoteEngine component\n" + s[end:]
open(p, "w").write(s)
print("quotes removed from app schema")
PY

echo ""
echo "stage2 written. Next:"
echo "  npx convex dev --once"
echo "  npx convex run seed:demo"
