#!/bin/bash
# Rewires the app to talk to the quoteEngine component.
# Run AFTER bidzy-component.sh stage2 pushes cleanly.
set -e
[ -d convex/quoteEngine ] || { echo "Run bidzy-component.sh stage2 first."; exit 1; }

echo "Rewiring app -> quoteEngine..."

# ---------------- jobs.board now asks the component ----------------
cat > convex/jobs.ts << 'EOF'
import { query, mutation } from "./_generated/server";
import { components } from "./_generated/api";
import { v } from "convex/values";

export const listByProject = query({
  args: { projectId: v.id("projects") },
  handler: async (ctx, { projectId }) =>
    ctx.db
      .query("jobs")
      .withIndex("by_project", (q) => q.eq("projectId", projectId))
      .collect(),
});

// The board. The app owns who was asked; the component owns what the
// prices mean. This query joins the two and owns neither.
export const board = query({
  args: { jobId: v.id("jobs") },
  handler: async (ctx, { jobId }) => {
    const job = await ctx.db.get(jobId);
    if (!job) return null;
    const project = await ctx.db.get(job.projectId);

    const invitations = await ctx.db
      .query("invitations")
      .withIndex("by_job", (q) => q.eq("jobId", jobId))
      .collect();

    const firms = await Promise.all(
      invitations.map((i) => ctx.db.get(i.firmId))
    );
    const firmById = new Map(firms.filter(Boolean).map((f) => [f._id, f]));

    // everything about price meaning comes from the component
    const analysis = await ctx.runQuery(components.quoteEngine.quotes.compare, {
      jobKey: String(jobId),
    });

    const quoteByParty = new Map(analysis.rows.map((r) => [r.partyKey, r]));

    const rows = invitations.map((inv) => {
      const firm = firmById.get(inv.firmId);
      const q = quoteByParty.get(String(inv.firmId)) ?? null;
      return {
        firmId: inv.firmId,
        firmName: firm?.name ?? "Unknown",
        firmEmail: firm?.email ?? "",
        licenceStatus: firm?.licenceStatus ?? "unknown",
        status: q ? "quoted" : inv.status,
        chaseCount: inv.chaseCount,
        quote: q
          ? {
              id: q.quoteId,
              total: q.total,
              comparable: q.comparable,
              hidden: q.hidden,
              gaps: q.gaps,
              currency: q.currency,
              lineItems: q.lineItems,
              exclusions: q.exclusions,
              inclusions: q.inclusions,
              stale: !q.valid,
              staleReason: q.invalidReason,
              needsReview: q.needsReview,
              receivedAt: q.receivedAt,
            }
          : null,
      };
    });

    return {
      job,
      projectRevision: project?.revision ?? 1,
      rows,
      allExclusions: analysis.allExclusions,
      benchmarks: analysis.benchmarks,
      lowest: analysis.cheapestComparable?.comparable ?? null,
      lowestParty: analysis.cheapestComparable?.partyName ?? null,
      headlineLowest: analysis.cheapestHeadline?.total ?? null,
      headlineParty: analysis.cheapestHeadline?.partyName ?? null,
      headlineMisleads: analysis.headlineMisleads,
      previousBest: analysis.previousBest?.comparable ?? null,
      lowestMoved: analysis.bestMoved,
      staleCount: analysis.invalidCount,
      quotedCount: analysis.quotedCount,
      invitedCount: invitations.length,
    };
  },
});

export const create = mutation({
  args: {
    projectId: v.id("projects"),
    name: v.string(),
    trade: v.string(),
    description: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const project = await ctx.db.get(args.projectId);
    return ctx.db.insert("jobs", {
      ...args,
      revision: project?.revision ?? 1,
      createdAt: Date.now(),
    });
  },
});

export const setInbox = mutation({
  args: {
    jobId: v.id("jobs"),
    inboxAddress: v.string(),
    inboxId: v.string(),
  },
  handler: async (ctx, { jobId, ...rest }) => ctx.db.patch(jobId, rest),
});
EOF

# ---------------- quotes.ts becomes a thin facade ----------------
cat > convex/quotes.ts << 'EOF'
import { mutation } from "./_generated/server";
import { components } from "./_generated/api";
import { v } from "convex/values";

const lineItem = v.object({
  label: v.string(),
  amount: v.optional(v.number()),
  note: v.optional(v.string()),
});

// The app never writes quote data directly. It hands what it received to
// the component, which decides what it means.
export const record = mutation({
  args: {
    jobId: v.id("jobs"),
    firmId: v.id("firms"),
    total: v.optional(v.number()),
    lineItems: v.optional(v.array(lineItem)),
    inclusions: v.optional(v.array(v.string())),
    exclusions: v.optional(v.array(v.string())),
    scopeTags: v.optional(v.array(v.string())),
    needsReview: v.optional(v.boolean()),
    rawText: v.optional(v.string()),
    sourceUrl: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const firm = await ctx.db.get(args.firmId);
    const job = await ctx.db.get(args.jobId);
    if (!firm || !job) throw new Error("unknown job or company");

    await ctx.runMutation(components.quoteEngine.quotes.record, {
      jobKey: String(args.jobId),
      partyKey: String(args.firmId),
      partyName: firm.name,
      total: args.total,
      lineItems: args.lineItems,
      inclusions: args.inclusions,
      exclusions: args.exclusions,
      scopeTags: args.scopeTags,
      needsReview: args.needsReview,
      rawText: args.rawText,
      sourceUrl: args.sourceUrl,
    });

    const invs = await ctx.db
      .query("invitations")
      .withIndex("by_job", (q) => q.eq("jobId", args.jobId))
      .collect();
    const inv = invs.find((i) => i.firmId === args.firmId);
    if (inv) await ctx.db.patch(inv._id, { status: "quoted" });

    await ctx.db.insert("events", {
      projectId: job.projectId,
      jobId: args.jobId,
      type: "quote_parsed",
      summary: `${firm.name} sent a price${
        args.total != null ? ` of $${args.total.toLocaleString()}` : ""
      }`,
      createdAt: Date.now(),
    });
  },
});

export const confirm = mutation({
  args: {
    quoteId: v.string(),
    total: v.optional(v.number()),
    exclusions: v.optional(v.array(v.string())),
    lineItems: v.optional(v.array(lineItem)),
  },
  handler: async (ctx, args) =>
    ctx.runMutation(components.quoteEngine.quotes.confirm, args),
});
EOF

# ---------------- scope change delegates validity to the component ----------------
python3 - << 'PY'
p = "convex/projects.ts"
s = open(p).read()

s = s.replace(
  'import { query, mutation } from "./_generated/server";',
  'import { query, mutation } from "./_generated/server";\nimport { components } from "./_generated/api";'
)

old_start = s.index("export const changeScope = mutation({")
old_end = s.index("export const resetStale = mutation({")
new_fn = '''export const changeScope = mutation({
  args: {
    projectId: v.id("projects"),
    newTag: v.optional(v.string()),
    label: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const project = await ctx.db.get(args.projectId);
    if (!project) throw new Error("no project");

    const newTag = args.newTag ?? "slate";
    const label = args.label ?? "Changed roofing material to slate";

    const jobs = await ctx.db
      .query("jobs")
      .withIndex("by_project", (q) => q.eq("projectId", args.projectId))
      .collect();

    // The app knows the job changed. Only the component knows which
    // prices that actually kills.
    let invalidated = [];
    let survived = [];
    for (const job of jobs) {
      const res = await ctx.runMutation(
        components.quoteEngine.quotes.invalidate,
        { jobKey: String(job._id), newTag, reason: label }
      );
      invalidated = invalidated.concat(res.invalidated);
      survived = survived.concat(res.survived);
    }

    if (invalidated.length === 0) {
      return { revision: project.revision, staleCount: 0, noop: true };
    }

    const next = project.revision + 1;
    await ctx.db.patch(args.projectId, {
      revision: next,
      scope: [newTag],
      scopeNote: label,
    });

    await ctx.db.insert("addenda", {
      projectId: args.projectId,
      revision: next,
      title: label,
      affectsTags: [newTag],
      createdAt: Date.now(),
    });

    await ctx.db.insert("events", {
      projectId: args.projectId,
      type: "scope_changed",
      summary: `You changed the job: ${label}`,
      meta: { revision: next, newTag },
      createdAt: Date.now(),
    });

    await ctx.db.insert("events", {
      projectId: args.projectId,
      type: "quote_stale",
      summary: `${invalidated.length} price${
        invalidated.length === 1 ? "" : "s"
      } no longer apply: ${invalidated.join(", ")}`,
      createdAt: Date.now() + 1,
    });

    if (survived.length) {
      await ctx.db.insert("events", {
        projectId: args.projectId,
        type: "quote_valid",
        summary: `${survived.join(", ")} already priced this - still valid`,
        createdAt: Date.now() + 2,
      });
    }

    await ctx.db.insert("events", {
      projectId: args.projectId,
      type: "reprice_requested",
      summary: `Asked ${invalidated.join(", ")} whether their price still holds`,
      createdAt: Date.now() + 3,
    });

    return { revision: next, staleCount: invalidated.length, invalidated, survived };
  },
});

'''
s = s[:old_start] + new_fn + s[old_end:]

# resetStale delegates too
rs_start = s.index("export const resetStale = mutation({")
new_reset = '''export const resetStale = mutation({
  args: { projectId: v.id("projects") },
  handler: async (ctx, { projectId }) => {
    const jobs = await ctx.db
      .query("jobs")
      .withIndex("by_project", (q) => q.eq("projectId", projectId))
      .collect();
    let restored = 0;
    for (const job of jobs) {
      const r = await ctx.runMutation(
        components.quoteEngine.quotes.revalidateAll,
        { jobKey: String(job._id) }
      );
      restored += r.restored;
    }
    await ctx.db.patch(projectId, {
      revision: 1,
      scope: ["asphalt-shingle"],
      scopeNote: "Asphalt shingle, full tear-off and replacement",
    });
    const olds = await ctx.db
      .query("addenda")
      .withIndex("by_project", (q) => q.eq("projectId", projectId))
      .collect();
    for (const a of olds) await ctx.db.delete(a._id);
    return { restored };
  },
});
'''
s = s[:rs_start] + new_reset
open(p, "w").write(s)
print("projects.ts rewired")
PY

# ---------------- inbound mail writes through the component ----------------
python3 - << 'PY'
p = "convex/mail.ts"
s = open(p).read()

s = s.replace(
  'import { internal } from "./_generated/api";',
  'import { internal, components } from "./_generated/api";'
)

start = s.index("    const existing = await ctx.db\n      .query(\"quotes\")")
end = s.index("    return { stored: true, matched: true, quoted: true };")
new_block = '''    await ctx.runMutation(components.quoteEngine.quotes.record, {
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

'''
s = s[:start] + new_block + s[end:]
open(p, "w").write(s)
print("mail.ts rewired")
PY

# ---------------- seed writes into the component ----------------
python3 - << 'PY'
p = "convex/seed.ts"
s = open(p).read()

s = s.replace(
  'import { mutation } from "./_generated/server";',
  'import { mutation } from "./_generated/server";\nimport { components } from "./_generated/api";'
)
s = s.replace('      "quotes", "invitations"', '      "invitations"')
s = s.replace('for (const t of [\n      "quotes",', 'for (const t of [')

# replace each ctx.db.insert("quotes", {...}) with a component call
import re
def to_component(m):
    body = m.group(1)
    body = body.replace("jobId, firmId: firmIds[0],", 'jobKey: String(jobId), partyKey: String(firmIds[0]), partyName: "Apex Roofing",')
    body = body.replace("jobId, firmId: firmIds[1],", 'jobKey: String(jobId), partyKey: String(firmIds[1]), partyName: "Crown Roof Systems",')
    body = body.replace("jobId, firmId: firmIds[2],", 'jobKey: String(jobId), partyKey: String(firmIds[2]), partyName: "PrimeBuild",')
    body = body.replace("jobId, firmId: firmIds[3],", 'jobKey: String(jobId), partyKey: String(firmIds[3]), partyName: "Skyline Exteriors",')
    body = re.sub(r"\s*revision: 1, stale: false,", "", body)
    body = re.sub(r"\s*receivedAt: [^,\n]+,", "", body)
    return "await ctx.runMutation(components.quoteEngine.quotes.record, {" + body + "});"

s = re.sub(r'await ctx\.db\.insert\("quotes", \{(.*?)\n    \}\);', lambda m: to_component(m), s, flags=re.S)

s = s.replace(
  "    const projectId = await ctx.db.insert(\"projects\", {",
  "    await ctx.runMutation(components.quoteEngine.quotes.clearAll, {});\n\n    const projectId = await ctx.db.insert(\"projects\", {"
)
open(p, "w").write(s)
print("seed.ts rewired")
PY

echo ""
echo "Rewired. Next:"
echo "  npx convex dev --once"
echo "  npx convex run seed:demo"
