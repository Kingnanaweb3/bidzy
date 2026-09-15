import { mutation } from "./_generated/server";

export const demo = mutation({
  args: {},
  handler: async (ctx) => {
    const projectId = await ctx.db.insert("projects", {
      name: "Riverside Medical Clinic",
      client: "Riverside Health Partners",
      revision: 1,
      createdAt: Date.now(),
    });

    const jobId = await ctx.db.insert("jobs", {
      projectId,
      name: "Windows & Glazing",
      trade: "glazing",
      description:
        "Supply and install all exterior windows and entrance glazing.",
      revision: 1,
      createdAt: Date.now(),
    });

    const firms = [
      {
        name: "Halcyon Glass Co.",
        email: "halcyon@example.com",
        trade: "glazing",
        licenceStatus: "valid" as const,
      },
      {
        name: "Northgate Glazing",
        email: "northgate@example.com",
        trade: "glazing",
        licenceStatus: "valid" as const,
      },
      {
        name: "Pearl City Windows",
        email: "pearl@example.com",
        trade: "glazing",
        licenceStatus: "expired" as const,
      },
      {
        name: "Vantage Facades",
        email: "vantage@example.com",
        trade: "glazing",
        licenceStatus: "valid" as const,
      },
    ];

    const firmIds = [];
    for (const f of firms) {
      firmIds.push(
        await ctx.db.insert("firms", { ...f, licenceCheckedAt: Date.now() })
      );
    }

    for (const firmId of firmIds) {
      await ctx.db.insert("invitations", {
        jobId,
        firmId,
        status: "sent",
        sentAt: Date.now(),
        chaseCount: 0,
      });
    }

    await ctx.db.insert("quotes", {
      jobId,
      firmId: firmIds[0],
      total: 180400,
      currency: "USD",
      lineItems: [
        { label: "Exterior windows (42 units)", amount: 131000 },
        { label: "Entrance glazing", amount: 28400 },
        { label: "Fireproofing to openings", amount: 12000 },
        { label: "Delivery & craneage", amount: 9000 },
      ],
      inclusions: ["Fireproofing", "Delivery", "Craneage", "Sales tax"],
      exclusions: ["Night work", "Temporary protection"],
      revision: 1,
      stale: false,
      needsReview: false,
      receivedAt: Date.now() - 86400000,
    });

    await ctx.db.insert("quotes", {
      jobId,
      firmId: firmIds[1],
      total: 168900,
      currency: "USD",
      lineItems: [
        { label: "Exterior windows (42 units)", amount: 133500 },
        { label: "Entrance glazing", amount: 26400 },
        { label: "Delivery", amount: 9000 },
      ],
      inclusions: ["Delivery"],
      exclusions: [
        "Fireproofing",
        "Craneage",
        "Sales tax",
        "Night work",
        "Temporary protection",
      ],
      revision: 1,
      stale: false,
      needsReview: false,
      receivedAt: Date.now() - 43200000,
    });

    await ctx.db.insert("quotes", {
      jobId,
      firmId: firmIds[2],
      total: 176250,
      currency: "USD",
      lineItems: [
        {
          label: "Windows & glazing, all-in",
          amount: 176250,
          note: "Lump sum, no breakdown given",
        },
      ],
      inclusions: ["Delivery", "Sales tax"],
      exclusions: ["Fireproofing", "Night work"],
      revision: 1,
      stale: false,
      needsReview: true,
      receivedAt: Date.now() - 7200000,
    });

    await ctx.db.insert("events", {
      projectId,
      jobId,
      type: "invite_sent",
      summary: "Invitations sent to 4 glazing firms",
      createdAt: Date.now() - 172800000,
    });

    return { projectId, jobId };
  },
});
