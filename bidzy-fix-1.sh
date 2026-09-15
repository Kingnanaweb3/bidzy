#!/bin/bash
# Bidzy fix 1 — selective staleness, idempotent design change, re-ranking.
# Run from the project root:  bash bidzy-fix-1.sh
set -e

if [ ! -d convex ]; then
  echo "Run this from the bidzy project root (the folder containing convex/)."
  exit 1
fi

echo "Patching schema, projects, jobs, seed..."

# ---------- schema: quotes gain an affectedBy tag set ----------
cat > convex/schema.ts << 'EOF'
import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  projects: defineTable({
    name: v.string(),
    client: v.optional(v.string()),
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

  quotes: defineTable({
    jobId: v.id("jobs"),
    firmId: v.id("firms"),
    invitationId: v.optional(v.id("invitations")),
    total: v.optional(v.number()),
    currency: v.string(),
    lineItems: v.array(
      v.object({
        label: v.string(),
        amount: v.optional(v.number()),
        note: v.optional(v.string()),
      })
    ),
    exclusions: v.array(v.string()),
    inclusions: v.array(v.string()),
    // which parts of the design this quote depends on
    scopeTags: v.optional(v.array(v.string())),
    revision: v.number(),
    stale: v.boolean(),
    staleReason: v.optional(v.string()),
    sourceUrl: v.optional(v.string()),
    rawText: v.optional(v.string()),
    needsReview: v.boolean(),
    receivedAt: v.number(),
  })
    .index("by_job", ["jobId"])
    .index("by_firm", ["firmId"]),

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
EOF

# ---------- projects: selective, idempotent design change ----------
cat > convex/projects.ts << 'EOF'
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
EOF

# ---------- jobs: board re-ranks survivors ----------
cat > convex/jobs.ts << 'EOF'
import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

export const listByProject = query({
  args: { projectId: v.id("projects") },
  handler: async (ctx, { projectId }) =>
    ctx.db
      .query("jobs")
      .withIndex("by_project", (q) => q.eq("projectId", projectId))
      .collect(),
});

export const board = query({
  args: { jobId: v.id("jobs") },
  handler: async (ctx, { jobId }) => {
    const job = await ctx.db.get(jobId);
    if (!job) return null;
    const project = await ctx.db.get(job.projectId);

    const invitations = await ctx.db
      .query("invitations")
      .withIndex("by_job", (q) => q.eq("jobId", jobId))
      .collect();

    const quotes = await ctx.db
      .query("quotes")
      .withIndex("by_job", (q) => q.eq("jobId", jobId))
      .collect();

    const firmIds = [
      ...new Set([
        ...invitations.map((i) => i.firmId),
        ...quotes.map((q) => q.firmId),
      ]),
    ];
    const firms = await Promise.all(firmIds.map((id) => ctx.db.get(id)));
    const firmById = new Map(firms.filter(Boolean).map((f) => [f._id, f]));

    const allExclusions = [...new Set(quotes.flatMap((q) => q.exclusions))].sort();

    const rows = firmIds.map((firmId) => {
      const firm = firmById.get(firmId);
      const quote = quotes.find((q) => q.firmId === firmId);
      const invitation = invitations.find((i) => i.firmId === firmId);
      return {
        firmId,
        firmName: firm?.name ?? "Unknown",
        firmEmail: firm?.email ?? "",
        licenceStatus: firm?.licenceStatus ?? "unknown",
        status: quote ? "quoted" : invitation?.status ?? "sent",
        chaseCount: invitation?.chaseCount ?? 0,
        quote: quote
          ? {
              id: quote._id,
              total: quote.total,
              currency: quote.currency,
              lineItems: quote.lineItems,
              exclusions: quote.exclusions,
              inclusions: quote.inclusions,
              stale: quote.stale,
              staleReason: quote.staleReason,
              needsReview: quote.needsReview,
              receivedAt: quote.receivedAt,
            }
          : null,
      };
    });

    // only live quotes compete
    const live = rows.filter(
      (r) => r.quote && !r.quote.stale && r.quote.total != null
    );
    const lowest = live.length
      ? Math.min(...live.map((r) => r.quote.total))
      : null;

    // what the previous winner was, before anything went stale
    const allPriced = rows.filter((r) => r.quote && r.quote.total != null);
    const previousLowest = allPriced.length
      ? Math.min(...allPriced.map((r) => r.quote.total))
      : null;
    const lowestMoved =
      lowest != null && previousLowest != null && lowest !== previousLowest;

    return {
      job,
      projectRevision: project?.revision ?? 1,
      rows,
      allExclusions,
      lowest,
      previousLowest,
      lowestMoved,
      liveCount: live.length,
      staleCount: rows.filter((r) => r.quote?.stale).length,
      quotedCount: rows.filter((r) => r.quote).length,
      invitedCount: rows.length,
    };
  },
});

export const create = mutation({
  args: {
    projectId: v.id("projects"),
    name: v.string(),
    trade: v.string(),
    description: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const project = await ctx.db.get(args.projectId);
    return ctx.db.insert("jobs", {
      ...args,
      revision: project?.revision ?? 1,
      createdAt: Date.now(),
    });
  },
});

export const setInbox = mutation({
  args: {
    jobId: v.id("jobs"),
    inboxAddress: v.string(),
    inboxId: v.string(),
  },
  handler: async (ctx, { jobId, ...rest }) => ctx.db.patch(jobId, rest),
});
EOF

# ---------- seed: scope tags, Vantage quotes the new spec, crane hire wording ----------
cat > convex/seed.ts << 'EOF'
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
EOF

echo ""
echo "Backend patched. Now patching the frontend..."

cat > src/components/Header.tsx << 'EOF'
import { useMutation, useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { useState } from "react";

export default function Header({ project }) {
  const publish = useMutation(api.projects.publishAddendum);
  const reset = useMutation(api.projects.resetStale);
  const addenda = useQuery(api.projects.addenda, { projectId: project._id });
  const [busy, setBusy] = useState(false);

  const published = (addenda?.length ?? 0) > 0;

  return (
    <header className="border-b border-stone-200 bg-white sticky top-0 z-10">
      <div className="mx-auto max-w-[1400px] px-6 py-4 flex items-center justify-between">
        <div className="flex items-baseline gap-4">
          <span className="text-xl font-bold tracking-tight">Bidzy</span>
          <span className="text-stone-300">/</span>
          <span className="text-sm text-stone-600">{project.name}</span>
          <span className="text-[11px] uppercase tracking-wide text-stone-400 border border-stone-200 rounded px-1.5 py-0.5">
            Design rev {project.revision}
          </span>
        </div>

        <div className="flex items-center gap-2">
          {published && (
            <button
              onClick={async () => {
                setBusy(true);
                await reset({ projectId: project._id });
                setBusy(false);
              }}
              disabled={busy}
              className="text-xs font-medium text-stone-500 hover:text-stone-900 px-3 py-2 transition disabled:opacity-40"
            >
              Reset demo
            </button>
          )}
          <button
            onClick={async () => {
              setBusy(true);
              await publish({ projectId: project._id });
              setBusy(false);
            }}
            disabled={busy || published}
            className="text-xs font-medium bg-stone-900 text-white px-3 py-2 rounded-md hover:bg-stone-700 transition disabled:bg-stone-200 disabled:text-stone-400"
          >
            {published ? "Addendum published" : "Publish design change"}
          </button>
        </div>
      </div>
    </header>
  );
}
EOF

cat > src/components/Board.tsx << 'EOF'
import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";

const money = (n) =>
  n == null ? "-" : "$" + n.toLocaleString(undefined, { maximumFractionDigits: 0 });

export default function Board({ jobId }) {
  const data = useQuery(api.jobs.board, { jobId });
  if (!data) return <p className="text-sm text-stone-400">Loading board...</p>;

  const {
    job,
    rows,
    allExclusions,
    lowest,
    previousLowest,
    lowestMoved,
    staleCount,
    quotedCount,
    invitedCount,
  } = data;

  return (
    <section>
      <div className="mb-6">
        <h1 className="text-2xl font-semibold tracking-tight">{job.name}</h1>
        <p className="text-sm text-stone-500 mt-1">
          {quotedCount} of {invitedCount} firms have priced this job
        </p>
      </div>

      {lowestMoved && (
        <div className="mb-5 rounded-lg border border-amber-200 bg-amber-50 px-4 py-3">
          <p className="text-sm text-amber-900">
            The design changed and {staleCount} quote
            {staleCount === 1 ? "" : "s"} no longer apply. The best valid price is
            now <strong>{money(lowest)}</strong>, up from {money(previousLowest)}.
          </p>
          <p className="text-xs text-amber-700 mt-1">
            Affected firms have been asked to confirm whether their price still
            holds.
          </p>
        </div>
      )}

      <div className="overflow-x-auto border border-stone-200 rounded-xl bg-white">
        <table className="w-full text-sm border-collapse">
          <thead>
            <tr className="border-b border-stone-200">
              <th className="text-left font-medium text-stone-500 px-5 py-3 w-[180px]">
                Firm
              </th>
              {rows.map((r) => (
                <th
                  key={r.firmId}
                  className="text-left px-5 py-3 min-w-[190px] align-top"
                >
                  <div
                    className={`font-semibold ${
                      r.quote?.stale ? "text-stone-400" : "text-stone-900"
                    }`}
                  >
                    {r.firmName}
                  </div>
                  <div className="flex items-center gap-1.5 mt-1.5 flex-wrap">
                    <Status status={r.status} stale={r.quote?.stale} />
                    {r.licenceStatus === "expired" && (
                      <span className="text-[10px] font-medium bg-red-50 text-red-700 border border-red-200 px-1.5 py-0.5 rounded">
                        Licence expired
                      </span>
                    )}
                  </div>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            <tr className="border-b border-stone-100">
              <Label>Quoted price</Label>
              {rows.map((r) => {
                const isLow =
                  r.quote?.total != null &&
                  r.quote.total === lowest &&
                  !r.quote.stale;
                return (
                  <td
                    key={r.firmId}
                    className={`px-5 py-4 transition-opacity duration-500 ${
                      r.quote?.stale ? "opacity-40" : ""
                    }`}
                  >
                    <div
                      className={`text-lg font-semibold tabular-nums ${
                        isLow
                          ? "text-emerald-700"
                          : r.quote?.stale
                          ? "text-stone-400 line-through decoration-stone-300"
                          : "text-stone-900"
                      }`}
                    >
                      {money(r.quote?.total)}
                    </div>
                    {isLow && (
                      <div className="text-[10px] uppercase tracking-wide text-emerald-700 mt-0.5">
                        Best valid price
                      </div>
                    )}
                    {r.quote?.stale && (
                      <div className="text-[10px] text-amber-700 mt-1 leading-tight">
                        Priced against the old design
                      </div>
                    )}
                    {r.quote?.needsReview && !r.quote?.stale && (
                      <div className="text-[10px] text-blue-700 mt-1">
                        Needs review
                      </div>
                    )}
                  </td>
                );
              })}
            </tr>

            <tr className="bg-stone-50">
              <td
                colSpan={rows.length + 1}
                className="px-5 py-2 text-[11px] uppercase tracking-widest text-stone-400"
              >
                What each firm will not do
              </td>
            </tr>

            {allExclusions.map((ex) => (
              <tr key={ex} className="border-b border-stone-100">
                <Label>{ex}</Label>
                {rows.map((r) => {
                  if (!r.quote)
                    return (
                      <td key={r.firmId} className="px-5 py-2.5 text-stone-300">
                        -
                      </td>
                    );
                  const excluded = r.quote.exclusions.includes(ex);
                  return (
                    <td
                      key={r.firmId}
                      className={`px-5 py-2.5 transition-opacity duration-500 ${
                        r.quote.stale ? "opacity-40" : ""
                      }`}
                    >
                      {excluded ? (
                        <span className="text-red-600 font-medium">
                          Not included
                        </span>
                      ) : (
                        <span className="text-emerald-700">Included</span>
                      )}
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <p className="text-xs text-stone-400 mt-3">
        A lower price with more exclusions is usually the more expensive bid.
      </p>
    </section>
  );
}

function Label({ children }) {
  return (
    <td className="px-5 py-2.5 text-stone-500 font-medium align-top">
      {children}
    </td>
  );
}

function Status({ status, stale }) {
  if (stale)
    return (
      <span className="text-[10px] font-medium border px-1.5 py-0.5 rounded bg-amber-50 text-amber-700 border-amber-200">
        Needs repricing
      </span>
    );
  const map = {
    quoted: "bg-emerald-50 text-emerald-700 border-emerald-200",
    sent: "bg-stone-50 text-stone-500 border-stone-200",
    opened: "bg-blue-50 text-blue-700 border-blue-200",
    replied: "bg-blue-50 text-blue-700 border-blue-200",
    declined: "bg-stone-50 text-stone-400 border-stone-200",
  };
  const text = {
    quoted: "Quoted",
    sent: "No reply yet",
    opened: "Opened",
    replied: "Replied",
    declined: "Declined",
  };
  return (
    <span
      className={`text-[10px] font-medium border px-1.5 py-0.5 rounded ${
        map[status] ?? map.sent
      }`}
    >
      {text[status] ?? status}
    </span>
  );
}
EOF

cat > src/components/Feed.tsx << 'EOF'
import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";

const DOT = {
  design_changed: "bg-amber-500",
  quote_stale: "bg-amber-400",
  reprice_requested: "bg-blue-500",
  quote_parsed: "bg-emerald-500",
  invite_sent: "bg-stone-400",
  reply_received: "bg-blue-500",
  licence_flag: "bg-red-500",
};

export default function Feed({ projectId }) {
  const events = useQuery(api.events.feed, { projectId, limit: 25 });

  return (
    <aside>
      <h2 className="text-[11px] uppercase tracking-widest text-stone-400 mb-4">
        Activity
      </h2>
      <div className="space-y-3">
        {events?.map((e) => (
          <div key={e._id} className="flex gap-3 text-sm">
            <span
              className={`mt-1.5 h-1.5 w-1.5 rounded-full shrink-0 ${
                DOT[e.type] ?? "bg-stone-300"
              }`}
            />
            <div>
              <p className="text-stone-700 leading-snug">{e.summary}</p>
              <p className="text-[11px] text-stone-400 mt-0.5">
                {new Date(e.createdAt).toLocaleString(undefined, {
                  month: "short",
                  day: "numeric",
                  hour: "numeric",
                  minute: "2-digit",
                })}
              </p>
            </div>
          </div>
        ))}
        {events && events.length === 0 && (
          <p className="text-sm text-stone-400">Nothing yet.</p>
        )}
      </div>
    </aside>
  );
}
EOF

echo ""
echo "Done. Re-run the seed to pick up the new data:"
echo "  npx convex run seed:demo"
