import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  // One record per company, keyed opaquely. The component never learns
  // what a firm is in the host app.
  records: defineTable({
    partyKey: v.string(),
    partyName: v.string(),
    region: v.optional(v.string()),

    status: v.union(
      v.literal("valid"),
      v.literal("expired"),
      v.literal("not_found"),
      v.literal("unknown")
    ),
    licenceNumber: v.optional(v.string()),
    expiresOn: v.optional(v.string()),
    registryName: v.optional(v.string()),

    // where this came from, so the claim can be checked
    sourceUrl: v.optional(v.string()),
    evidence: v.optional(v.string()),

    checkedAt: v.optional(v.number()),
    confident: v.boolean(),
  })
    .index("by_party", ["partyKey"])
    .index("by_status", ["status"]),

  // every check ever run, so a lapse has a date attached
  checks: defineTable({
    partyKey: v.string(),
    status: v.string(),
    sourceUrl: v.optional(v.string()),
    at: v.number(),
  }).index("by_party", ["partyKey"]),
});
