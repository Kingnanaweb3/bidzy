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
