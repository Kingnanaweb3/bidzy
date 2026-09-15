import { mutation } from "./_generated/server";

export const demo = mutation({
  args: {},
  handler: async (ctx) => {
    // wipe first so re-seeding is safe
    for (const t of [
      "quotes",
      "invitations",
      "firms",
      "jobs",
      "events",
      "addenda",
      "monitors",
      "messages",
      "projects",
    ]) {
      const rows = await ctx.db.query(t).collect();
      for (const r of rows) await ctx.db.delete(r._id);
    }

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
        licenceStatus: "valid",
      },
      {
        name: "Northgate Glazing",
        email: "northgate@example.com",
        trade: "glazing",
        licenceStatus: "valid",
      },
      {
        name: "Pearl City Windows",
        email: "pearl@example.com",
        trade: "glazing",
        licenceStatus: "expired",
      },
      {
        name: "Vantage Facades",
        email: "vantage@example.com",
        trade: "glazing",
        licenceStatus: "valid",
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

    const DAY = 86400000;

    // Halcyon - honest, complete, priced the OLD spec
    await ctx.db.insert("quotes", {
      jobId,
      firmId: firmIds[0],
      total: 180400,
      currency: "USD",
      lineItems: [
        { label: "Exterior windows (42 units)", amount: 131000 },
        { label: "Entrance glazing", amount: 28400 },
        { label: "Fireproofing to openings", amount: 12000 },
        { label: "Delivery & crane hire", amount: 9000 },
      ],
      inclusions: ["Fireproofing", "Delivery", "Crane hire", "Sales tax"],
      exclusions: ["Night work", "Temporary protection"],
      scopeTags: ["glazing-spec", "exterior-windows"],
      revision: 1,
      stale: false,
      needsReview: false,
      receivedAt: Date.now() - 3 * DAY,
    });

    // Northgate - cheapest on paper, excludes the expensive bits. OLD spec.
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
        "Crane hire",
        "Sales tax",
        "Night work",
        "Temporary protection",
      ],
      scopeTags: ["glazing-spec", "exterior-windows"],
      revision: 1,
      stale: false,
      needsReview: false,
      receivedAt: Date.now() - 2 * DAY,
    });

    // Pearl City - lump sum, unclear, expired licence. OLD spec.
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
      inclusions: ["Delivery", "Sales tax", "Crane hire", "Temporary protection"],
      exclusions: ["Fireproofing", "Night work"],
      scopeTags: ["glazing-spec", "exterior-windows"],
      revision: 1,
      stale: false,
      needsReview: true,
      receivedAt: Date.now() - DAY,
    });

    // Vantage - entrance glazing only, does NOT depend on the exterior spec.
    // Survives the addendum. This is the point.
    await ctx.db.insert("quotes", {
      jobId,
      firmId: firmIds[3],
      total: 174600,
      currency: "USD",
      lineItems: [
        { label: "Exterior windows (42 units)", amount: 129200 },
        { label: "Entrance glazing", amount: 27400 },
        { label: "Fireproofing to openings", amount: 10500 },
        { label: "Delivery & crane hire", amount: 7500 },
      ],
      inclusions: [
        "Fireproofing",
        "Delivery",
        "Crane hire",
        "Sales tax",
        "Temporary protection",
      ],
      exclusions: ["Night work"],
      // priced the updated spec already - quoted late, off the current drawings
      scopeTags: ["exterior-windows"],
      revision: 1,
      stale: false,
      needsReview: false,
      receivedAt: Date.now() - 7200000,
    });

    await ctx.db.insert("events", {
      projectId,
      jobId,
      type: "invite_sent",
      summary: "Invitations sent to 4 glazing firms",
      createdAt: Date.now() - 5 * DAY,
    });

    await ctx.db.insert("events", {
      projectId,
      jobId,
      type: "quote_parsed",
      summary: "Vantage Facades quoted $174,600 - priced off the current drawings",
      createdAt: Date.now() - 7100000,
    });

    return { projectId, jobId };
  },
});
