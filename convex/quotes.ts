import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

const lineItem = v.object({
  label: v.string(),
  amount: v.optional(v.number()),
  note: v.optional(v.string()),
});

export const record = mutation({
  args: {
    jobId: v.id("jobs"),
    firmId: v.id("firms"),
    invitationId: v.optional(v.id("invitations")),
    total: v.optional(v.number()),
    currency: v.optional(v.string()),
    lineItems: v.optional(v.array(lineItem)),
    exclusions: v.optional(v.array(v.string())),
    inclusions: v.optional(v.array(v.string())),
    sourceUrl: v.optional(v.string()),
    rawText: v.optional(v.string()),
    needsReview: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const job = await ctx.db.get(args.jobId);
    if (!job) throw new Error("no job");
    const project = await ctx.db.get(job.projectId);
    const firm = await ctx.db.get(args.firmId);

    const quoteId = await ctx.db.insert("quotes", {
      jobId: args.jobId,
      firmId: args.firmId,
      invitationId: args.invitationId,
      total: args.total,
      currency: args.currency ?? "USD",
      lineItems: args.lineItems ?? [],
      exclusions: args.exclusions ?? [],
      inclusions: args.inclusions ?? [],
      revision: project?.revision ?? 1,
      stale: false,
      sourceUrl: args.sourceUrl,
      rawText: args.rawText,
      needsReview: args.needsReview ?? false,
      receivedAt: Date.now(),
    });

    if (args.invitationId) {
      await ctx.db.patch(args.invitationId, { status: "quoted" });
    }

    await ctx.db.insert("events", {
      projectId: job.projectId,
      jobId: args.jobId,
      type: "quote_parsed",
      summary: `${firm?.name ?? "A firm"} quoted ${
        args.total != null ? "$" + args.total.toLocaleString() : "an unpriced bid"
      }`,
      meta: { quoteId },
      createdAt: Date.now(),
    });

    return quoteId;
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
  },
});

export const listByJob = query({
  args: { jobId: v.id("jobs") },
  handler: async (ctx, { jobId }) =>
    ctx.db
      .query("quotes")
      .withIndex("by_job", (q) => q.eq("jobId", jobId))
      .collect(),
});
