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
