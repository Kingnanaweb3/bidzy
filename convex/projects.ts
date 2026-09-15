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

export const addenda = query({
  args: { projectId: v.id("projects") },
  handler: async (ctx, { projectId }) =>
    ctx.db
      .query("addenda")
      .withIndex("by_project", (q) => q.eq("projectId", projectId))
      .order("desc")
      .collect(),
});

// Publish a design change. Only quotes that depend on the changed part
// of the design go stale — everything else stays live and gets re-ranked.
export const publishAddendum = mutation({
  args: {
    projectId: v.id("projects"),
    title: v.optional(v.string()),
    affectsTags: v.optional(v.array(v.string())),
  },
  handler: async (ctx, args) => {
    const project = await ctx.db.get(args.projectId);
    if (!project) throw new Error("no project");

    const affectsTags = args.affectsTags ?? ["glazing-spec"];
    const title =
      args.title ?? "Addendum 3 - exterior glazing spec changed to low-E triple";

    // idempotent: if every dependent quote is already stale, do nothing
    const jobs = await ctx.db
      .query("jobs")
      .withIndex("by_project", (q) => q.eq("projectId", args.projectId))
      .collect();

    const affected = [];
    for (const job of jobs) {
      const quotes = await ctx.db
        .query("quotes")
        .withIndex("by_job", (q) => q.eq("jobId", job._id))
        .collect();
      for (const quote of quotes) {
        const tags = quote.scopeTags ?? [];
        const touched = tags.some((t) => affectsTags.includes(t));
        if (touched && !quote.stale) affected.push(quote);
      }
    }

    if (affected.length === 0) {
      return { revision: project.revision, staleCount: 0, noop: true };
    }

    const next = project.revision + 1;
    await ctx.db.patch(args.projectId, { revision: next });

    await ctx.db.insert("addenda", {
      projectId: args.projectId,
      revision: next,
      title,
      affectsTags,
      createdAt: Date.now(),
    });

    for (const quote of affected) {
      await ctx.db.patch(quote._id, {
        stale: true,
        staleReason: title,
      });
    }

    const firmNames = [];
    for (const quote of affected) {
      const firm = await ctx.db.get(quote.firmId);
      if (firm) firmNames.push(firm.name);
    }

    await ctx.db.insert("events", {
      projectId: args.projectId,
      type: "design_changed",
      summary: title,
      meta: { revision: next, affectsTags },
      createdAt: Date.now(),
    });

    await ctx.db.insert("events", {
      projectId: args.projectId,
      type: "quote_stale",
      summary: `${affected.length} quote${
        affected.length === 1 ? "" : "s"
      } now priced against the old design: ${firmNames.join(", ")}`,
      meta: { count: affected.length },
      createdAt: Date.now() + 1,
    });

    await ctx.db.insert("events", {
      projectId: args.projectId,
      type: "reprice_requested",
      summary: `Asked ${firmNames.join(", ")} to confirm whether their price still holds`,
      createdAt: Date.now() + 2,
    });

    return { revision: next, staleCount: affected.length, firmNames };
  },
});

// kept for convenience / reset during the demo
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
    await ctx.db.patch(projectId, { revision: 1 });
    const olds = await ctx.db
      .query("addenda")
      .withIndex("by_project", (q) => q.eq("projectId", projectId))
      .collect();
    for (const a of olds) await ctx.db.delete(a._id);
    return { restored: n };
  },
});
