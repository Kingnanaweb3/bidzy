import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  projects: defineTable({
    name: v.string(),
    client: v.optional(v.string()),
    scope: v.optional(v.array(v.string())),
    scopeNote: v.optional(v.string()),
    dueAt: v.optional(v.number()),
    planUrl: v.optional(v.string()),
    revision: v.number(),
    createdAt: v.number(),
  }),

  jobs: defineTable({
    projectId: v.id("projects"),
    name: v.string(),
    trade: v.string(),
    description: v.optional(v.string()),
    inboxAddress: v.optional(v.string()),
    inboxId: v.optional(v.string()),
    revision: v.number(),
    createdAt: v.number(),
  }).index("by_project", ["projectId"]),

  firms: defineTable({
    name: v.string(),
    email: v.string(),
    trade: v.string(),
    phone: v.optional(v.string()),
    licenceNumber: v.optional(v.string()),
    licenceStatus: v.optional(
      v.union(v.literal("valid"), v.literal("expired"), v.literal("unknown"))
    ),
    licenceCheckedAt: v.optional(v.number()),
  }).index("by_email", ["email"]),

  invitations: defineTable({
    jobId: v.id("jobs"),
    firmId: v.id("firms"),
    status: v.union(
      v.literal("sent"),
      v.literal("opened"),
      v.literal("replied"),
      v.literal("declined"),
      v.literal("quoted")
    ),
    sentAt: v.number(),
    lastChasedAt: v.optional(v.number()),
    chaseCount: v.number(),
    threadId: v.optional(v.string()),
  })
    .index("by_job", ["jobId"])
    .index("by_firm", ["firmId"]),

  // quotes now live in the quoteEngine component


  messages: defineTable({
    jobId: v.id("jobs"),
    firmId: v.optional(v.id("firms")),
    direction: v.union(v.literal("in"), v.literal("out")),
    subject: v.optional(v.string()),
    body: v.string(),
    fromAddress: v.string(),
    toAddress: v.string(),
    threadId: v.optional(v.string()),
    messageId: v.optional(v.string()),
    attachments: v.array(
      v.object({
        filename: v.string(),
        url: v.string(),
        contentType: v.optional(v.string()),
      })
    ),
    kind: v.optional(v.string()),
    createdAt: v.number(),
  })
    .index("by_job", ["jobId"])
    .index("by_thread", ["threadId"]),

  events: defineTable({
    projectId: v.id("projects"),
    jobId: v.optional(v.id("jobs")),
    type: v.string(),
    summary: v.string(),
    meta: v.optional(v.any()),
    createdAt: v.number(),
  })
    .index("by_project", ["projectId"])
    .index("by_job", ["jobId"]),

  // a published change to the design
  addenda: defineTable({
    projectId: v.id("projects"),
    revision: v.number(),
    title: v.string(),
    affectsTags: v.array(v.string()),
    sourceUrl: v.optional(v.string()),
    createdAt: v.number(),
  }).index("by_project", ["projectId"]),

  monitors: defineTable({
    projectId: v.id("projects"),
    url: v.string(),
    label: v.string(),
    lastHash: v.optional(v.string()),
    lastCheckedAt: v.optional(v.number()),
    active: v.boolean(),
  }).index("by_project", ["projectId"]),
});
