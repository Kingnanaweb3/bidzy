import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

export const listByProject = query({
  args: { projectId: v.id("projects") },
  handler: async (ctx, { projectId }) =>
    ctx.db
      .query("jobs")
      .withIndex("by_project", (q) => q.eq("projectId", projectId))
      .collect(),
});

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

    const quotes = await ctx.db
      .query("quotes")
      .withIndex("by_job", (q) => q.eq("jobId", jobId))
      .collect();

    const firmIds = [
      ...new Set([
        ...invitations.map((i) => i.firmId),
        ...quotes.map((q) => q.firmId),
      ]),
    ];
    const firms = await Promise.all(firmIds.map((id) => ctx.db.get(id)));
    const firmById = new Map(
      firms.filter(Boolean).map((f) => [f._id, f])
    );

    const allExclusions = [
      ...new Set(quotes.flatMap((q) => q.exclusions)),
    ].sort();

    const rows = firmIds.map((firmId) => {
      const firm = firmById.get(firmId);
      const quote = quotes.find((q) => q.firmId === firmId);
      const invitation = invitations.find((i) => i.firmId === firmId);
      return {
        firmId,
        firmName: firm?.name ?? "Unknown",
        firmEmail: firm?.email ?? "",
        licenceStatus: firm?.licenceStatus ?? "unknown",
        status: quote ? "quoted" : invitation?.status ?? "sent",
        chaseCount: invitation?.chaseCount ?? 0,
        quote: quote
          ? {
              id: quote._id,
              total: quote.total,
              currency: quote.currency,
              lineItems: quote.lineItems,
              exclusions: quote.exclusions,
              inclusions: quote.inclusions,
              stale: quote.stale,
              needsReview: quote.needsReview,
              receivedAt: quote.receivedAt,
            }
          : null,
      };
    });

    const live = rows.filter(
      (r) => r.quote && !r.quote.stale && r.quote.total != null
    );
    const lowest = live.length
      ? Math.min(...live.map((r) => r.quote.total))
      : null;

    return {
      job,
      projectRevision: project?.revision ?? 1,
      rows,
      allExclusions,
      lowest,
      quotedCount: rows.filter((r) => r.quote).length,
      invitedCount: rows.length,
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
