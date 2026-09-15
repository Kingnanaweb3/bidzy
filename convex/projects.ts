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

    // a quote survives only if it already covered the new scope
    const affected = [];
    const survivors = [];
    for (const job of jobs) {
      const quotes = await ctx.db
        .query("quotes")
        .withIndex("by_job", (q) => q.eq("jobId", job._id))
        .collect();
      for (const quote of quotes) {
        const tags = quote.scopeTags ?? [];
        if (tags.includes(newTag)) survivors.push(quote);
        else if (!quote.stale) affected.push(quote);
      }
    }

    if (affected.length === 0) {
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

    for (const quote of affected) {
      await ctx.db.patch(quote._id, { stale: true, staleReason: label });
    }

    const names = [];
    for (const quote of affected) {
      const firm = await ctx.db.get(quote.firmId);
      if (firm) names.push(firm.name);
    }
    const survivorNames = [];
    for (const quote of survivors) {
      const firm = await ctx.db.get(quote.firmId);
      if (firm) survivorNames.push(firm.name);
    }

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
      summary: `${affected.length} quote${
        affected.length === 1 ? "" : "s"
      } priced the old job and no longer apply: ${names.join(", ")}`,
      createdAt: Date.now() + 1,
    });

    if (survivorNames.length) {
      await ctx.db.insert("events", {
        projectId: args.projectId,
        type: "quote_valid",
        summary: `${survivorNames.join(", ")} already priced this - still valid`,
        createdAt: Date.now() + 2,
      });
    }

    await ctx.db.insert("events", {
      projectId: args.projectId,
      type: "reprice_requested",
      summary: `Asked ${names.join(", ")} whether their price still holds`,
      createdAt: Date.now() + 3,
    });

    return { revision: next, staleCount: affected.length, names, survivorNames };
  },
});

export const resetStale = mutation({
  args: { projectId: v.id("projects") },
  handler: async (ctx, { projectId }) => {
    const jobs = await ctx.db
      .query("jobs")
      .withIndex("by_project", (q) => q.eq("projectId", projectId))
      .collect();
    let n = 0;
    for (const job of jobs) {
      const quotes = await ctx.db
        .query("quotes")
        .withIndex("by_job", (q) => q.eq("jobId", job._id))
        .collect();
      for (const quote of quotes) {
        if (quote.stale) {
          await ctx.db.patch(quote._id, { stale: false, staleReason: undefined });
          n++;
        }
      }
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
    return { restored: n };
  },
});
