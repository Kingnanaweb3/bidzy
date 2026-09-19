import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

export const forJob = query({
  args: { partyKeys: v.array(v.string()) },
  handler: async (ctx, { partyKeys }) => {
    const out = [];
    for (const key of partyKeys) {
      const r = await ctx.db
        .query("records")
        .withIndex("by_party", (q) => q.eq("partyKey", key))
        .first();
      if (r) out.push(r);
    }
    return out;
  },
});

export const get = query({
  args: { partyKey: v.string() },
  handler: async (ctx, { partyKey }) =>
    ctx.db
      .query("records")
      .withIndex("by_party", (q) => q.eq("partyKey", partyKey))
      .first(),
});

export const history = query({
  args: { partyKey: v.string() },
  handler: async (ctx, { partyKey }) =>
    ctx.db
      .query("checks")
      .withIndex("by_party", (q) => q.eq("partyKey", partyKey))
      .order("desc")
      .take(10),
});

// Everything the host knows about a company before any check has run.
export const seed = mutation({
  args: {
    partyKey: v.string(),
    partyName: v.string(),
    region: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("records")
      .withIndex("by_party", (q) => q.eq("partyKey", args.partyKey))
      .first();
    if (existing) return existing._id;
    return ctx.db.insert("records", {
      ...args,
      status: "unknown",
      confident: false,
    });
  },
});

// The result of a real lookup. Keeping every check means "expired since
// Tuesday" is a fact with a date, not an impression.
export const record = mutation({
  args: {
    partyKey: v.string(),
    partyName: v.string(),
    status: v.union(
      v.literal("valid"),
      v.literal("expired"),
      v.literal("not_found"),
      v.literal("unknown")
    ),
    licenceNumber: v.optional(v.string()),
    expiresOn: v.optional(v.string()),
    registryName: v.optional(v.string()),
    sourceUrl: v.optional(v.string()),
    evidence: v.optional(v.string()),
    confident: v.boolean(),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const existing = await ctx.db
      .query("records")
      .withIndex("by_party", (q) => q.eq("partyKey", args.partyKey))
      .first();

    const changed = existing && existing.status !== args.status;

    const doc = { ...args, checkedAt: now };
    if (existing) {
      await ctx.db.patch(existing._id, doc);
    } else {
      await ctx.db.insert("records", doc);
    }

    await ctx.db.insert("checks", {
      partyKey: args.partyKey,
      status: args.status,
      sourceUrl: args.sourceUrl,
      at: now,
    });

    return { changed: !!changed, from: existing?.status ?? null, to: args.status };
  },
});

export const clearAll = mutation({
  args: {},
  handler: async (ctx) => {
    for (const t of ["records", "checks"]) {
      const rows = await ctx.db.query(t).collect();
      for (const r of rows) await ctx.db.delete(r._id);
    }
    return { cleared: true };
  },
});
