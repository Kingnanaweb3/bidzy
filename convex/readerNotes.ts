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
