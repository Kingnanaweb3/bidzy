import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  quotes: defineTable({
    // Opaque keys. Ids don't cross the component boundary, so the host
    // passes strings and the component never learns what a job or a
    // company actually is.
    jobKey: v.string(),
    partyKey: v.string(),
    partyName: v.string(),

    total: v.optional(v.number()),
    currency: v.string(),
    lineItems: v.array(
      v.object({
        label: v.string(),
        amount: v.optional(v.number()),
        note: v.optional(v.string()),
      })
    ),
    inclusions: v.array(v.string()),
    exclusions: v.array(v.string()),

    // which parts of the job this price depends on
    scopeTags: v.array(v.string()),

    valid: v.boolean(),
    invalidReason: v.optional(v.string()),
    needsReview: v.boolean(),

    rawText: v.optional(v.string()),
    sourceUrl: v.optional(v.string()),
    receivedAt: v.number(),
  })
    .index("by_job", ["jobKey"])
    .index("by_job_party", ["jobKey", "partyKey"]),

  // what the market says a given exclusion costs, learned from the
  // quotes that did price it
  benchmarks: defineTable({
    jobKey: v.string(),
    label: v.string(),
    amount: v.number(),
    samples: v.number(),
  }).index("by_job_label", ["jobKey", "label"]),
});
