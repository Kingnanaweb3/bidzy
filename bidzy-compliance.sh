#!/bin/bash
# A second component: is this company allowed to do the work?
# Run:  bash bidzy-compliance.sh stage1   (then convex dev --once)
#       bash bidzy-compliance.sh stage2
set -e
[ -d convex/quoteEngine ] || { echo "Run from the bidzy project root."; exit 1; }
STAGE="${1:-}"

if [ "$STAGE" = "stage1" ]; then
mkdir -p convex/compliance

cat > convex/compliance/convex.config.ts << 'EOF'
import { defineComponent } from "convex/server";

// Whether a company is allowed to do the work. Separate from what their
// price means: a licence can lapse without a number changing, and a price
// can go stale without anything happening to the licence. Different
// reasons to change, so different components.
export default defineComponent("compliance");
EOF

cat > convex/compliance/schema.ts << 'EOF'
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
EOF

cat > convex/compliance/licences.ts << 'EOF'
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
EOF

python3 - << 'PY'
p = "convex/convex.config.ts"
s = open(p).read()
if "compliance" not in s:
    s = s.replace(
        'import quoteEngine from "./quoteEngine/convex.config";',
        'import quoteEngine from "./quoteEngine/convex.config";\nimport compliance from "./compliance/convex.config";'
    )
    s = s.replace(
        "app.use(quoteEngine);",
        '''app.use(quoteEngine);

// Owns whether a company is allowed to do the work, and the evidence for
// saying so. Nothing else can write to it.
app.use(compliance);'''
    )
    open(p, "w").write(s)
    print("compliance registered")
PY

echo ""
echo "stage1 done. Now:  npx convex dev --once"
echo "Then:              bash bidzy-compliance.sh stage2"
exit 0
fi

if [ "$STAGE" != "stage2" ]; then
  echo "Pass stage1 or stage2."
  exit 1
fi

# ---- the lookup itself ----
cat > convex/verify.ts << 'EOF'
"use node";
import { action, internalAction } from "./_generated/server";
import { internal, api, components } from "./_generated/api";
import { v } from "convex/values";

// Contractor licences are public record. Every state publishes a register
// and anyone can look a company up — which is exactly why nobody does it
// for twenty companies by hand.
const SCHEMA = {
  type: "object",
  properties: {
    found: { type: "boolean", description: "Whether a licence record for this company was found" },
    status: {
      type: "string",
      description: "One of: valid, expired, not_found. Use expired if the record shows lapsed, suspended, revoked or an expiry date in the past.",
    },
    licenceNumber: { type: "string" },
    expiresOn: { type: "string", description: "Expiry date as written on the register" },
    registryName: { type: "string", description: "The body publishing the record" },
    evidence: { type: "string", description: "The sentence on the page that supports this, under 25 words" },
    confident: { type: "boolean" },
  },
  required: ["found", "status"],
};

async function lookUp(name: string, region: string) {
  const key = process.env.FIRECRAWL_API_KEY;
  if (!key) throw new Error("FIRECRAWL_API_KEY is not set");

  const res = await fetch("https://api.firecrawl.dev/v2/search", {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      query: `"${name}" roofing contractor licence OR license register ${region}`,
      limit: 4,
      scrapeOptions: {
        formats: ["markdown", { type: "json", schema: SCHEMA }],
      },
    }),
  });

  const body = await res.text();
  if (!res.ok) throw new Error(`Firecrawl ${res.status}: ${body.slice(0, 300)}`);
  const parsed = JSON.parse(body);
  const results = parsed.data?.web ?? parsed.data ?? [];

  for (const r of results) {
    const j = r.json ?? {};
    if (j.found && j.status && j.status !== "not_found") {
      return { ...j, sourceUrl: r.url };
    }
  }
  return { found: false, status: "not_found", confident: false, sourceUrl: results[0]?.url };
}

export const checkOne = internalAction({
  args: { firmId: v.id("firms"), firmName: v.string(), region: v.optional(v.string()) },
  handler: async (ctx, { firmId, firmName, region }) => {
    let result: any;
    try {
      result = await lookUp(firmName, region ?? "United States");
    } catch (e: any) {
      return { failed: String(e.message ?? e) };
    }

    const status =
      result.status === "valid" || result.status === "expired" || result.status === "not_found"
        ? result.status
        : "unknown";

    const outcome = await ctx.runMutation(components.compliance.licences.record, {
      partyKey: String(firmId),
      partyName: firmName,
      status,
      licenceNumber: result.licenceNumber ? String(result.licenceNumber) : undefined,
      expiresOn: result.expiresOn ? String(result.expiresOn) : undefined,
      registryName: result.registryName ? String(result.registryName) : undefined,
      sourceUrl: result.sourceUrl ? String(result.sourceUrl) : undefined,
      evidence: result.evidence ? String(result.evidence).slice(0, 220) : undefined,
      confident: result.confident !== false,
    });

    await ctx.runMutation(internal.verifyNotes.note, {
      firmId,
      firmName,
      status,
      changed: outcome.changed,
      from: outcome.from ?? undefined,
      sourceUrl: result.sourceUrl ? String(result.sourceUrl) : undefined,
    });

    return { status, sourceUrl: result.sourceUrl };
  },
});

// Check everyone on a job. Twenty companies is a morning by hand.
export const checkAll = action({
  args: { jobId: v.id("jobs") },
  handler: async (ctx, { jobId }) => {
    const board = await ctx.runQuery(api.jobs.board, { jobId });
    if (!board) throw new Error("no job");

    const done = [];
    for (const row of board.rows) {
      const r = await ctx.runAction(internal.verify.checkOne, {
        firmId: row.firmId,
        firmName: row.firmName,
      });
      done.push({ firm: row.firmName, ...r });
    }
    return { checked: done.length, done };
  },
});
EOF

cat > convex/verifyNotes.ts << 'EOF'
import { internalMutation, mutation } from "./_generated/server";
import { components } from "./_generated/api";
import { v } from "convex/values";

export const note = internalMutation({
  args: {
    firmId: v.id("firms"),
    firmName: v.string(),
    status: v.string(),
    changed: v.boolean(),
    from: v.optional(v.string()),
    sourceUrl: v.optional(v.string()),
  },
  handler: async (ctx, a) => {
    const firm = await ctx.db.get(a.firmId);
    if (firm) {
      await ctx.db.patch(a.firmId, {
        licenceStatus:
          a.status === "valid" ? "valid" : a.status === "expired" ? "expired" : "unknown",
        licenceCheckedAt: Date.now(),
      });
    }

    const job = await ctx.db.query("jobs").first();
    if (!job) return;

    const summary =
      a.status === "expired"
        ? `${a.firmName}'s licence shows as expired on the public register`
        : a.status === "valid"
        ? `${a.firmName}'s licence checks out`
        : `No licence record found for ${a.firmName}`;

    await ctx.db.insert("events", {
      projectId: job.projectId,
      jobId: job._id,
      type: a.status === "expired" ? "licence_flag" : "licence_checked",
      summary: a.changed && a.from ? `${summary} — was ${a.from} last time` : summary,
      meta: a.sourceUrl ? { sourceUrl: a.sourceUrl } : undefined,
      createdAt: Date.now(),
    });
  },
});

// Put every company on the job into the component before any check runs.
export const seedAll = mutation({
  args: {},
  handler: async (ctx) => {
    const firms = await ctx.db.query("firms").collect();
    for (const f of firms) {
      await ctx.runMutation(components.compliance.licences.seed, {
        partyKey: String(f._id),
        partyName: f.name,
      });
    }
    return { seeded: firms.length };
  },
});
EOF

# ---- the board reads the component ----
python3 - << 'PY'
p = "convex/jobs.ts"
s = open(p).read()

if "compliance" not in s:
    s = s.replace(
        '''    // everything about price meaning comes from the component
    const analysis = await ctx.runQuery(components.quoteEngine.quotes.compare, {
      jobKey: String(jobId),
    });''',
        '''    // everything about price meaning comes from one component
    const analysis = await ctx.runQuery(components.quoteEngine.quotes.compare, {
      jobKey: String(jobId),
    });

    // whether they're allowed to do the work comes from another
    const licences = await ctx.runQuery(components.compliance.licences.forJob, {
      partyKeys: invitations.map((i) => String(i.firmId)),
    });
    const licenceByParty = new Map(licences.map((l) => [l.partyKey, l]));'''
    )

    s = s.replace(
        '''        licenceStatus: firm?.licenceStatus ?? "unknown",''',
        '''        licence: licenceByParty.get(String(inv.firmId)) ?? null,
        licenceStatus:
          licenceByParty.get(String(inv.firmId))?.status ??
          firm?.licenceStatus ??
          "unknown",'''
    )
    open(p, "w").write(s)
    print("board reads both components")
PY

# ---- UI: the badge becomes evidence you can click ----
python3 - << 'PY'
import pathlib

p = pathlib.Path("src/components/Board.tsx")
s = p.read_text()
s = s.replace(
    '''                    {r.licenceStatus === "expired" && (
                      <Chip tone="bad">expired</Chip>
                    )}''',
    '''                    {r.licenceStatus === "expired" && (
                      <a
                        href={r.licence?.sourceUrl ?? undefined}
                        target="_blank"
                        rel="noreferrer"
                        title={r.licence?.evidence ?? "Licence shows as expired"}
                      >
                        <Chip tone="bad">licence expired</Chip>
                      </a>
                    )}
                    {r.licenceStatus === "not_found" && (
                      <Chip tone="neutral">no licence found</Chip>
                    )}'''
)
p.write_text(s)

p = pathlib.Path("src/components/BoardMobile.tsx")
s = p.read_text()
s = s.replace(
    '''                  {r.licenceStatus === "expired" && (
                    <Chip tone="bad">expired</Chip>
                  )}''',
    '''                  {r.licenceStatus === "expired" && (
                    <Chip tone="bad">licence expired</Chip>
                  )}
                  {r.licenceStatus === "not_found" && (
                    <Chip tone="neutral">no licence</Chip>
                  )}'''
)
p.write_text(s)
print("badges link to their source")
PY

# ---- a button to run it ----
python3 - << 'PY'
p = "src/pages/InboxPage.tsx"
s = open(p).read()
if "verifyAll" not in s:
    s = s.replace(
        "  const attach = useMutation(api.mail.attachSender);",
        "  const attach = useMutation(api.mail.attachSender);\n  const verifyAll = useAction(api.verify.checkAll);"
    )
    s = s.replace(
        '''              <Ghost disabled={!!busy} onClick={() => run("reprice", () => reprice({ jobId }))}>
                {busy === "reprice" ? "Sending…" : "Ask to reprice"}
              </Ghost>''',
        '''              <Ghost disabled={!!busy} onClick={() => run("reprice", () => reprice({ jobId }))}>
                {busy === "reprice" ? "Sending…" : "Ask to reprice"}
              </Ghost>
              <Ghost disabled={!!busy} onClick={() => run("verify", () => verifyAll({ jobId }))}>
                {busy === "verify" ? "Checking…" : "Check licences"}
              </Ghost>'''
    )
    open(p, "w").write(s)
    print("check licences button added")
PY

python3 - << 'PY'
p = "src/components/Feed.tsx"
s = open(p).read()
s = s.replace(
  '  gave_up: "bg-[#F87171]",',
  '  gave_up: "bg-[#F87171]",\n  licence_flag: "bg-[#F87171]",\n  licence_checked: "bg-[#4ADE80]",'
)
open(p, "w").write(s)
print("feed tones for licences")
PY

echo ""
echo "stage2 done. Then:"
echo "  npx convex dev --once"
echo "  npx convex run verifyNotes:seedAll"
