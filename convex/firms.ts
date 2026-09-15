import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

export const list = query({
  args: {},
  handler: async (ctx) => ctx.db.query("firms").collect(),
});

export const create = mutation({
  args: {
    name: v.string(),
    email: v.string(),
    trade: v.string(),
    phone: v.optional(v.string()),
    licenceNumber: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("firms")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .first();
    if (existing) return existing._id;
    return ctx.db.insert("firms", { ...args, licenceStatus: "unknown" });
  },
});

export const setLicence = mutation({
  args: {
    firmId: v.id("firms"),
    licenceStatus: v.union(
      v.literal("valid"),
      v.literal("expired"),
      v.literal("unknown")
    ),
  },
  handler: async (ctx, { firmId, licenceStatus }) =>
    ctx.db.patch(firmId, { licenceStatus, licenceCheckedAt: Date.now() }),
});
