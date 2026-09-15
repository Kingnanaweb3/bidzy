import { query } from "./_generated/server";
import { v } from "convex/values";

export const feed = query({
  args: { projectId: v.id("projects"), limit: v.optional(v.number()) },
  handler: async (ctx, { projectId, limit }) =>
    ctx.db
      .query("events")
      .withIndex("by_project", (q) => q.eq("projectId", projectId))
      .order("desc")
      .take(limit ?? 30),
});
