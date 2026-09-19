import { internalMutation, mutation } from "./_generated/server";
import { components } from "./_generated/api";
import { v } from "convex/values";

export const note = internalMutation({
  args: {
    firmId: v.id("firms"),
    firmName: v.string(),
    status: v.string(),
    changed: v.boolean(),
    from: v.optional(v.string()),
    sourceUrl: v.optional(v.string()),
  },
  handler: async (ctx, a) => {
    const firm = await ctx.db.get(a.firmId);
    if (firm) {
      await ctx.db.patch(a.firmId, {
        licenceStatus:
          a.status === "valid" ? "valid" : a.status === "expired" ? "expired" : "unknown",
        licenceCheckedAt: Date.now(),
      });
    }

    const job = await ctx.db.query("jobs").first();
    if (!job) return;

    const summary =
      a.status === "expired"
        ? `${a.firmName}'s licence shows as expired on the public register`
        : a.status === "valid"
        ? `${a.firmName}'s licence checks out on the public register`
        : `Couldn't verify ${a.firmName} — no official register listed them`;

    await ctx.db.insert("events", {
      projectId: job.projectId,
      jobId: job._id,
      type: a.status === "expired" ? "licence_flag" : "licence_checked",
      summary: a.changed && a.from ? `${summary} — was ${a.from} last time` : summary,
      meta: a.sourceUrl ? { sourceUrl: a.sourceUrl } : undefined,
      createdAt: Date.now(),
    });
  },
});

// Put every company on the job into the component before any check runs.
export const seedAll = mutation({
  args: {},
  handler: async (ctx) => {
    const firms = await ctx.db.query("firms").collect();
    for (const f of firms) {
      await ctx.runMutation(components.compliance.licences.seed, {
        partyKey: String(f._id),
        partyName: f.name,
      });
    }
    return { seeded: firms.length };
  },
});
