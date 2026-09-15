import { query, mutation } from "./_generated/server";
import { components } from "./_generated/api";
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
  args: { name: v.string(), client: v.optional(v.string()) },
  handler: async (ctx, args) =>
    ctx.db.insert("projects", { ...args, revision: 1, createdAt: Date.now() }),
});

export const addenda = query({
  args: { projectId: v.id("projects") },
  handler: async (ctx, { projectId }) =>
    ctx.db
      .query("addenda")
      .withIndex("by_project", (q) => q.eq("projectId", projectId))
      .order("desc")
      .collect(),
});

// The homeowner changes what they want. Quotes that priced the old
// thing are no longer valid; quotes that covered the new one survive.
export const changeScope = mutation({
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

export const resetStale = mutation({
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
