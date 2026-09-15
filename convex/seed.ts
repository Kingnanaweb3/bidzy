import { mutation } from "./_generated/server";
import { components } from "./_generated/api";

export const demo = mutation({
  args: {},
  handler: async (ctx) => {
    for (const t of [
      "invitations", "firms", "jobs", "events",
      "addenda", "monitors", "messages", "projects",
    ]) {
      const rows = await ctx.db.query(t).collect();
      for (const r of rows) await ctx.db.delete(r._id);
    }

    await ctx.runMutation(components.quoteEngine.quotes.clearAll, {});

    const projectId = await ctx.db.insert("projects", {
      name: "Roof replacement",
      client: "42 Marlow Street",
      scope: ["asphalt-shingle"],
      scopeNote: "Asphalt shingle, full tear-off and replacement",
      revision: 1,
      createdAt: Date.now(),
    });

    const jobId = await ctx.db.insert("jobs", {
      projectId,
      name: "Roof replacement",
      trade: "roofing",
      description:
        "Full tear-off and replacement of the roof on a 3-bedroom house. Materials, labour, removal and disposal.",
      revision: 1,
      createdAt: Date.now(),
    });

    const firms = [
      { name: "Apex Roofing", email: "apex@example.com", trade: "roofing", licenceStatus: "valid" },
      { name: "Crown Roof Systems", email: "crown@example.com", trade: "roofing", licenceStatus: "valid" },
      { name: "PrimeBuild", email: "prime@example.com", trade: "roofing", licenceStatus: "expired" },
      { name: "Skyline Exteriors", email: "skyline@example.com", trade: "roofing", licenceStatus: "valid" },
    ];

    const firmIds = [];
    for (const f of firms) {
      firmIds.push(await ctx.db.insert("firms", { ...f, licenceCheckedAt: Date.now() }));
    }

    for (const firmId of firmIds) {
      await ctx.db.insert("invitations", {
        jobId, firmId, status: "sent", sentAt: Date.now(), chaseCount: 0,
      });
    }

    const DAY = 86400000;

    // Apex - complete, honest, asphalt
    await ctx.runMutation(components.quoteEngine.quotes.record, {
      jobKey: String(jobId), partyKey: String(firmIds[0]), partyName: "Apex Roofing", total: 14200, currency: "USD",
      lineItems: [
        { label: "Tear-off and disposal", amount: 2400 },
        { label: "Asphalt shingle, supply", amount: 6100 },
        { label: "Labour", amount: 4500 },
        { label: "Delivery and skip hire", amount: 1200 },
      ],
      inclusions: ["Removal and disposal", "Delivery", "Skip hire", "Sales tax", "5-year workmanship warranty"],
      exclusions: ["Gutter replacement"],
      scopeTags: ["asphalt-shingle"], needsReview: false,});

    // Crown - cheapest on paper, hides the expensive parts
    await ctx.runMutation(components.quoteEngine.quotes.record, {
      jobKey: String(jobId), partyKey: String(firmIds[1]), partyName: "Crown Roof Systems", total: 11900, currency: "USD",
      lineItems: [
        { label: "Asphalt shingle, supply and fit", amount: 10700 },
        { label: "Labour", amount: 1200 },
      ],
      inclusions: ["Labour"],
      exclusions: ["Removal and disposal", "Delivery", "Skip hire", "Sales tax", "Gutter replacement"],
      scopeTags: ["asphalt-shingle"], needsReview: false,});

    // PrimeBuild - lump sum, vague, expired licence
    await ctx.runMutation(components.quoteEngine.quotes.record, {
      jobKey: String(jobId), partyKey: String(firmIds[2]), partyName: "PrimeBuild", total: 13450, currency: "USD",
      lineItems: [
        { label: "Complete roof replacement", amount: 13450, note: "Lump sum, no breakdown given" },
      ],
      inclusions: ["Removal and disposal", "Delivery", "Sales tax"],
      exclusions: ["Skip hire", "Gutter replacement"],
      scopeTags: ["asphalt-shingle"], needsReview: true,});

    // Skyline - quoted slate as well. Survives the material change.
    await ctx.runMutation(components.quoteEngine.quotes.record, {
      jobKey: String(jobId), partyKey: String(firmIds[3]), partyName: "Skyline Exteriors", total: 15800, currency: "USD",
      lineItems: [
        { label: "Tear-off and disposal", amount: 2600 },
        { label: "Slate, supply", amount: 7400 },
        { label: "Labour", amount: 4600 },
        { label: "Delivery and skip hire", amount: 1200 },
      ],
      inclusions: ["Removal and disposal", "Delivery", "Skip hire", "Sales tax", "10-year workmanship warranty"],
      exclusions: ["Gutter replacement"],
      // priced both materials, so a switch to slate does not invalidate it
      scopeTags: ["asphalt-shingle", "slate"], needsReview: false,});

    await ctx.db.insert("events", {
      projectId, jobId, type: "invite_sent",
      summary: "Asked 4 roofing companies for a price",
      createdAt: Date.now() - 5 * DAY,
    });

    await ctx.db.insert("events", {
      projectId, jobId, type: "quote_parsed",
      summary: "Skyline Exteriors quoted for slate as well as asphalt",
      createdAt: Date.now() - 7100000,
    });

    return { projectId, jobId };
  },
});
