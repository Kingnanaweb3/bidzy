import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

export const list = query({
  args: {},
  handler: async (ctx) => ctx.db.query("projects").collect(),
});

export const get = query({
  args: { projectId: v.id("projects") },
  handler: async (ctx, { projectId }) => ctx.db.get(projectId),
});

export const create = mutation({
  args: {
    name: v.string(),
    client: v.optional(v.string()),
    planUrl: v.optional(v.string()),
  },
  handler: async (ctx, args) =>
    ctx.db.insert("projects", { ...args, revision: 1, createdAt: Date.now() }),
});

export const bumpRevision = mutation({
  args: { projectId: v.id("projects"), note: v.optional(v.string()) },
  handler: async (ctx, { projectId, note }) => {
    const project = await ctx.db.get(projectId);
    if (!project) throw new Error("no project");
    const next = project.revision + 1;
    await ctx.db.patch(projectId, { revision: next });

    const jobs = await ctx.db
      .query("jobs")
      .withIndex("by_project", (q) => q.eq("projectId", projectId))
      .collect();

    let staleCount = 0;
    for (const job of jobs) {
      const quotes = await ctx.db
        .query("quotes")
        .withIndex("by_job", (q) => q.eq("jobId", job._id))
        .collect();
      for (const quote of quotes) {
        if (quote.revision < next && !quote.stale) {
          await ctx.db.patch(quote._id, { stale: true });
          staleCount++;
        }
      }
    }

    await ctx.db.insert("events", {
      projectId,
      type: "design_changed",
      summary: note ?? `Design updated to revision ${next}`,
      meta: { revision: next, staleCount },
      createdAt: Date.now(),
    });

    return { revision: next, staleCount };
  },
});
