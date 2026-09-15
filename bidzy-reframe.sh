#!/bin/bash
# Bidzy reframe: construction estimator -> homeowner.
# Same mechanic, new user. Run from project root.
set -e
[ -d convex ] || { echo "Run from the bidzy project root."; exit 1; }

echo "Reframing to the homeowner story..."

# ---------------- schema: projects gain scope, jobs become the project ----------------
python3 - << 'PY'
import re
p = "convex/schema.ts"
s = open(p).read()

# projects: add scope + scopeLabel
s = s.replace(
  """  projects: defineTable({
    name: v.string(),
    client: v.optional(v.string()),""",
  """  projects: defineTable({
    name: v.string(),
    client: v.optional(v.string()),
    scope: v.optional(v.array(v.string())),
    scopeNote: v.optional(v.string()),"""
)
open(p, "w").write(s)
print("schema patched")
PY

# ---------------- seed: homeowner roof project ----------------
cat > convex/seed.ts << 'EOF'
import { mutation } from "./_generated/server";

export const demo = mutation({
  args: {},
  handler: async (ctx) => {
    for (const t of [
      "quotes", "invitations", "firms", "jobs", "events",
      "addenda", "monitors", "messages", "projects",
    ]) {
      const rows = await ctx.db.query(t).collect();
      for (const r of rows) await ctx.db.delete(r._id);
    }

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
    await ctx.db.insert("quotes", {
      jobId, firmId: firmIds[0], total: 14200, currency: "USD",
      lineItems: [
        { label: "Tear-off and disposal", amount: 2400 },
        { label: "Asphalt shingle, supply", amount: 6100 },
        { label: "Labour", amount: 4500 },
        { label: "Delivery and skip hire", amount: 1200 },
      ],
      inclusions: ["Removal and disposal", "Delivery", "Skip hire", "Sales tax", "5-year workmanship warranty"],
      exclusions: ["Gutter replacement"],
      scopeTags: ["asphalt-shingle"],
      revision: 1, stale: false, needsReview: false,
      receivedAt: Date.now() - 3 * DAY,
    });

    // Crown - cheapest on paper, hides the expensive parts
    await ctx.db.insert("quotes", {
      jobId, firmId: firmIds[1], total: 11900, currency: "USD",
      lineItems: [
        { label: "Asphalt shingle, supply and fit", amount: 10700 },
        { label: "Labour", amount: 1200 },
      ],
      inclusions: ["Labour"],
      exclusions: ["Removal and disposal", "Delivery", "Skip hire", "Sales tax", "Gutter replacement"],
      scopeTags: ["asphalt-shingle"],
      revision: 1, stale: false, needsReview: false,
      receivedAt: Date.now() - 2 * DAY,
    });

    // PrimeBuild - lump sum, vague, expired licence
    await ctx.db.insert("quotes", {
      jobId, firmId: firmIds[2], total: 13450, currency: "USD",
      lineItems: [
        { label: "Complete roof replacement", amount: 13450, note: "Lump sum, no breakdown given" },
      ],
      inclusions: ["Removal and disposal", "Delivery", "Sales tax"],
      exclusions: ["Skip hire", "Gutter replacement"],
      scopeTags: ["asphalt-shingle"],
      revision: 1, stale: false, needsReview: true,
      receivedAt: Date.now() - DAY,
    });

    // Skyline - quoted slate as well. Survives the material change.
    await ctx.db.insert("quotes", {
      jobId, firmId: firmIds[3], total: 15800, currency: "USD",
      lineItems: [
        { label: "Tear-off and disposal", amount: 2600 },
        { label: "Slate, supply", amount: 7400 },
        { label: "Labour", amount: 4600 },
        { label: "Delivery and skip hire", amount: 1200 },
      ],
      inclusions: ["Removal and disposal", "Delivery", "Skip hire", "Sales tax", "10-year workmanship warranty"],
      exclusions: ["Gutter replacement"],
      // priced both materials, so a switch to slate does not invalidate it
      scopeTags: ["asphalt-shingle", "slate"],
      revision: 1, stale: false, needsReview: false,
      receivedAt: Date.now() - 7200000,
    });

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
EOF

# ---------------- projects: scope change instead of addendum ----------------
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
  args: { name: v.string(), client: v.optional(v.string()) },
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

// The homeowner changes what they want. Quotes that priced the old
// thing are no longer valid; quotes that covered the new one survive.
export const changeScope = mutation({
  args: {
    projectId: v.id("projects"),
    newTag: v.optional(v.string()),
    label: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const project = await ctx.db.get(args.projectId);
    if (!project) throw new Error("no project");

    const newTag = args.newTag ?? "slate";
    const label = args.label ?? "Changed roofing material to slate";

    const jobs = await ctx.db
      .query("jobs")
      .withIndex("by_project", (q) => q.eq("projectId", args.projectId))
      .collect();

    // a quote survives only if it already covered the new scope
    const affected = [];
    const survivors = [];
    for (const job of jobs) {
      const quotes = await ctx.db
        .query("quotes")
        .withIndex("by_job", (q) => q.eq("jobId", job._id))
        .collect();
      for (const quote of quotes) {
        const tags = quote.scopeTags ?? [];
        if (tags.includes(newTag)) survivors.push(quote);
        else if (!quote.stale) affected.push(quote);
      }
    }

    if (affected.length === 0) {
      return { revision: project.revision, staleCount: 0, noop: true };
    }

    const next = project.revision + 1;
    await ctx.db.patch(args.projectId, {
      revision: next,
      scope: [newTag],
      scopeNote: label,
    });

    await ctx.db.insert("addenda", {
      projectId: args.projectId,
      revision: next,
      title: label,
      affectsTags: [newTag],
      createdAt: Date.now(),
    });

    for (const quote of affected) {
      await ctx.db.patch(quote._id, { stale: true, staleReason: label });
    }

    const names = [];
    for (const quote of affected) {
      const firm = await ctx.db.get(quote.firmId);
      if (firm) names.push(firm.name);
    }
    const survivorNames = [];
    for (const quote of survivors) {
      const firm = await ctx.db.get(quote.firmId);
      if (firm) survivorNames.push(firm.name);
    }

    await ctx.db.insert("events", {
      projectId: args.projectId,
      type: "scope_changed",
      summary: `You changed the job: ${label}`,
      meta: { revision: next, newTag },
      createdAt: Date.now(),
    });

    await ctx.db.insert("events", {
      projectId: args.projectId,
      type: "quote_stale",
      summary: `${affected.length} quote${
        affected.length === 1 ? "" : "s"
      } priced the old job and no longer apply: ${names.join(", ")}`,
      createdAt: Date.now() + 1,
    });

    if (survivorNames.length) {
      await ctx.db.insert("events", {
        projectId: args.projectId,
        type: "quote_valid",
        summary: `${survivorNames.join(", ")} already priced this - still valid`,
        createdAt: Date.now() + 2,
      });
    }

    await ctx.db.insert("events", {
      projectId: args.projectId,
      type: "reprice_requested",
      summary: `Asked ${names.join(", ")} whether their price still holds`,
      createdAt: Date.now() + 3,
    });

    return { revision: next, staleCount: affected.length, names, survivorNames };
  },
});

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
    await ctx.db.patch(projectId, {
      revision: 1,
      scope: ["asphalt-shingle"],
      scopeNote: "Asphalt shingle, full tear-off and replacement",
    });
    const olds = await ctx.db
      .query("addenda")
      .withIndex("by_project", (q) => q.eq("projectId", projectId))
      .collect();
    for (const a of olds) await ctx.db.delete(a._id);
    return { restored: n };
  },
});
EOF

# ---------------- UI: homeowner language ----------------
cat > src/components/Header.tsx << 'EOF'
import { useMutation, useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { useState } from "react";

export default function Header({ project }) {
  const change = useMutation(api.projects.changeScope);
  const reset = useMutation(api.projects.resetStale);
  const addenda = useQuery(api.projects.addenda, { projectId: project._id });
  const [busy, setBusy] = useState(false);

  const changed = (addenda?.length ?? 0) > 0;

  return (
    <header className="border-b border-stone-200 bg-white sticky top-0 z-10">
      <div className="mx-auto max-w-[1400px] px-6 py-4 flex items-center justify-between">
        <div className="flex items-baseline gap-4 min-w-0">
          <span className="text-xl font-bold tracking-tight">Bidzy</span>
          <span className="text-stone-300">/</span>
          <span className="text-sm text-stone-600 truncate">
            {project.name} - {project.client}
          </span>
        </div>

        <div className="flex items-center gap-3">
          <span className="text-[11px] text-stone-500 hidden md:inline">
            {project.scopeNote}
          </span>
          {changed && (
            <button
              onClick={async () => {
                setBusy(true);
                await reset({ projectId: project._id });
                setBusy(false);
              }}
              disabled={busy}
              className="text-xs font-medium text-stone-500 hover:text-stone-900 px-3 py-2 transition disabled:opacity-40"
            >
              Undo
            </button>
          )}
          <button
            onClick={async () => {
              setBusy(true);
              await change({ projectId: project._id });
              setBusy(false);
            }}
            disabled={busy || changed}
            className="text-xs font-medium bg-stone-900 text-white px-3 py-2 rounded-md hover:bg-stone-700 transition disabled:bg-stone-200 disabled:text-stone-400"
          >
            {changed ? "Job changed" : "Change to slate instead"}
          </button>
        </div>
      </div>
    </header>
  );
}
EOF

python3 - << 'PY'
p = "src/components/Board.tsx"
s = open(p).read()

s = s.replace(
  "{quotedCount} of {invitedCount} firms have priced this job",
  "{quotedCount} of {invitedCount} companies have sent a price"
)
s = s.replace("What each firm will not do", "What each price does not cover")
s = s.replace('className="text-left font-medium text-stone-500 px-5 py-3 w-[180px]">\n                Firm',
              'className="text-left font-medium text-stone-500 px-5 py-3 w-[180px]">\n                Company')
s = s.replace("Firm\n              </th>", "Company\n              </th>")
s = s.replace(
  "The design changed and {staleCount} quote",
  "You changed the job and {staleCount} quote"
)
s = s.replace(
  "Affected firms have been asked to confirm whether their price still\n            holds.",
  "We've emailed them to ask whether their price still holds."
)
s = s.replace("Priced against the old design", "Priced the old job")
s = s.replace(
  "A lower price with more exclusions is usually the more expensive bid.",
  "The cheapest price is rarely the cheapest job. Check what it leaves out."
)
s = s.replace('{r.firmName}', '{r.firmName}')
open(p, "w").write(s)
print("board copy patched")
PY

python3 - << 'PY'
p = "src/components/Feed.tsx"
s = open(p).read()
s = s.replace(
  'design_changed: "bg-amber-500",',
  'scope_changed: "bg-amber-500",\n  design_changed: "bg-amber-500",\n  quote_valid: "bg-emerald-500",'
)
open(p, "w").write(s)
print("feed patched")
PY

python3 - << 'PY'
p = "src/components/Inbox.tsx"
s = open(p).read()
s = s.replace("This job's inbox", "This project's inbox")
s = s.replace("Ask firms for a price", "Ask for prices")
s = s.replace("Chase non-responders", "Chase who hasn't replied")
s = s.replace("Ask stale firms to reprice", "Ask affected companies to reprice")
s = s.replace(
  "No email yet. Create the inbox, then ask the firms for a price.",
  "No email yet. Create the inbox, then ask the companies for a price."
)
open(p, "w").write(s)
print("inbox patched")
PY

python3 - << 'PY'
p = "convex/agentmail.ts"
s = open(p).read()
s = s.replace("Riverside Medical Clinic", "42 Marlow Street")
s = s.replace("Riverside Health Partners", "the homeowner")
s = s.replace(
  "The architect has issued a change to the glazing spec since you priced this job.",
  "The homeowner has changed the job since you sent your price."
)
s = s.replace(
  "Your quote of $${row.quote.total?.toLocaleString()} was against the previous drawings.",
  "Your price of $${row.quote.total?.toLocaleString()} was for the original job."
)
s = s.replace(
  "Design change - does your price for ${data.job.name} still hold?",
  "The job has changed - does your price still hold?"
)
open(p, "w").write(s)
print("email copy patched")
PY

cat > index.html << 'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Bidzy - keeps your contractor quotes honest</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

echo ""
echo "Reframed. Now:"
echo "  npx convex run seed:demo"
echo "  then set real emails again:"
echo "  npx convex run firmsAdmin:setEmails '{\"pairs\":[{\"name\":\"Apex\",\"email\":\"...\"},...]}'"
