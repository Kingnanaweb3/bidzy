#!/bin/bash
# Bidzy — full project setup. Run from inside an empty project folder:
#   bash bidzy-setup.sh
set -e

echo "Writing Bidzy project files into $(pwd)"

mkdir -p convex src/components src/lib public docs

# ---------- guard against Yarn PnP leaking from a parent dir ----------
cat > .yarnrc.yml << 'EOF'
nodeLinker: node-modules
enableGlobalCache: false
EOF

# ---------- config ----------
cat > package.json << 'EOF'
{
  "name": "bidzy",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "preview": "vite preview",
    "seed": "convex run seed:demo",
    "deploy": "convex deploy --cmd 'npm run build'"
  },
  "dependencies": {
    "convex": "^1.17.0",
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": {
    "@types/react": "^18.3.12",
    "@types/react-dom": "^18.3.1",
    "@vitejs/plugin-react": "^4.3.3",
    "autoprefixer": "^10.4.20",
    "postcss": "^8.4.49",
    "tailwindcss": "^3.4.15",
    "typescript": "^5.6.3",
    "vite": "^5.4.11"
  }
}
EOF

cat > vite.config.ts << 'EOF'
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  build: { outDir: "dist" },
});
EOF

cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true
  },
  "include": ["src", "convex"]
}
EOF

cat > tailwind.config.js << 'EOF'
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: { extend: {} },
  plugins: [],
};
EOF

cat > postcss.config.js << 'EOF'
export default { plugins: { tailwindcss: {}, autoprefixer: {} } };
EOF

cat > .gitignore << 'EOF'
node_modules
dist
.env
.env.local
.DS_Store
convex/_generated
EOF

cat > .env.example << 'EOF'
CONVEX_DEPLOYMENT=
VITE_CONVEX_URL=
AGENTMAIL_API_KEY=
AGENTMAIL_DOMAIN=
FIRECRAWL_API_KEY=
EOF

cat > index.html << 'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Bidzy - quotes that chase themselves</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

# ---------- convex schema ----------
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
    revision: v.number(),
    stale: v.boolean(),
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

# ---------- convex functions ----------
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

export const bumpRevision = mutation({
  args: { projectId: v.id("projects"), note: v.optional(v.string()) },
  handler: async (ctx, { projectId, note }) => {
    const project = await ctx.db.get(projectId);
    if (!project) throw new Error("no project");
    const next = project.revision + 1;
    await ctx.db.patch(projectId, { revision: next });

    const jobs = await ctx.db
      .query("jobs")
      .withIndex("by_project", (q) => q.eq("projectId", projectId))
      .collect();

    let staleCount = 0;
    for (const job of jobs) {
      const quotes = await ctx.db
        .query("quotes")
        .withIndex("by_job", (q) => q.eq("jobId", job._id))
        .collect();
      for (const quote of quotes) {
        if (quote.revision < next && !quote.stale) {
          await ctx.db.patch(quote._id, { stale: true });
          staleCount++;
        }
      }
    }

    await ctx.db.insert("events", {
      projectId,
      type: "design_changed",
      summary: note ?? `Design updated to revision ${next}`,
      meta: { revision: next, staleCount },
      createdAt: Date.now(),
    });

    return { revision: next, staleCount };
  },
});
EOF

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
    const firmById = new Map(
      firms.filter(Boolean).map((f) => [f._id, f])
    );

    const allExclusions = [
      ...new Set(quotes.flatMap((q) => q.exclusions)),
    ].sort();

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
              needsReview: quote.needsReview,
              receivedAt: quote.receivedAt,
            }
          : null,
      };
    });

    const live = rows.filter(
      (r) => r.quote && !r.quote.stale && r.quote.total != null
    );
    const lowest = live.length
      ? Math.min(...live.map((r) => r.quote.total))
      : null;

    return {
      job,
      projectRevision: project?.revision ?? 1,
      rows,
      allExclusions,
      lowest,
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

cat > convex/quotes.ts << 'EOF'
import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

const lineItem = v.object({
  label: v.string(),
  amount: v.optional(v.number()),
  note: v.optional(v.string()),
});

export const record = mutation({
  args: {
    jobId: v.id("jobs"),
    firmId: v.id("firms"),
    invitationId: v.optional(v.id("invitations")),
    total: v.optional(v.number()),
    currency: v.optional(v.string()),
    lineItems: v.optional(v.array(lineItem)),
    exclusions: v.optional(v.array(v.string())),
    inclusions: v.optional(v.array(v.string())),
    sourceUrl: v.optional(v.string()),
    rawText: v.optional(v.string()),
    needsReview: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const job = await ctx.db.get(args.jobId);
    if (!job) throw new Error("no job");
    const project = await ctx.db.get(job.projectId);
    const firm = await ctx.db.get(args.firmId);

    const quoteId = await ctx.db.insert("quotes", {
      jobId: args.jobId,
      firmId: args.firmId,
      invitationId: args.invitationId,
      total: args.total,
      currency: args.currency ?? "USD",
      lineItems: args.lineItems ?? [],
      exclusions: args.exclusions ?? [],
      inclusions: args.inclusions ?? [],
      revision: project?.revision ?? 1,
      stale: false,
      sourceUrl: args.sourceUrl,
      rawText: args.rawText,
      needsReview: args.needsReview ?? false,
      receivedAt: Date.now(),
    });

    if (args.invitationId) {
      await ctx.db.patch(args.invitationId, { status: "quoted" });
    }

    await ctx.db.insert("events", {
      projectId: job.projectId,
      jobId: args.jobId,
      type: "quote_parsed",
      summary: `${firm?.name ?? "A firm"} quoted ${
        args.total != null ? "$" + args.total.toLocaleString() : "an unpriced bid"
      }`,
      meta: { quoteId },
      createdAt: Date.now(),
    });

    return quoteId;
  },
});

export const confirm = mutation({
  args: {
    quoteId: v.id("quotes"),
    total: v.optional(v.number()),
    exclusions: v.optional(v.array(v.string())),
    lineItems: v.optional(v.array(lineItem)),
  },
  handler: async (ctx, { quoteId, ...patch }) => {
    const clean = Object.fromEntries(
      Object.entries(patch).filter(([, val]) => val !== undefined)
    );
    await ctx.db.patch(quoteId, { ...clean, needsReview: false });
  },
});

export const listByJob = query({
  args: { jobId: v.id("jobs") },
  handler: async (ctx, { jobId }) =>
    ctx.db
      .query("quotes")
      .withIndex("by_job", (q) => q.eq("jobId", jobId))
      .collect(),
});
EOF

cat > convex/firms.ts << 'EOF'
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
EOF

cat > convex/events.ts << 'EOF'
import { query } from "./_generated/server";
import { v } from "convex/values";

export const feed = query({
  args: { projectId: v.id("projects"), limit: v.optional(v.number()) },
  handler: async (ctx, { projectId, limit }) =>
    ctx.db
      .query("events")
      .withIndex("by_project", (q) => q.eq("projectId", projectId))
      .order("desc")
      .take(limit ?? 30),
});
EOF

cat > convex/seed.ts << 'EOF'
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
EOF

# ---------- frontend ----------
cat > src/index.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root { color-scheme: light; }
body {
  margin: 0;
  background: #faf9f7;
  color: #1c1917;
  font-family: ui-sans-serif, -apple-system, "Segoe UI", Inter, system-ui, sans-serif;
  -webkit-font-smoothing: antialiased;
}
EOF

cat > src/main.tsx << 'EOF'
import React from "react";
import ReactDOM from "react-dom/client";
import { ConvexProvider, ConvexReactClient } from "convex/react";
import App from "./App";
import "./index.css";

const convex = new ConvexReactClient(import.meta.env.VITE_CONVEX_URL as string);

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <ConvexProvider client={convex}>
      <App />
    </ConvexProvider>
  </React.StrictMode>
);
EOF

cat > src/App.tsx << 'EOF'
import { useQuery } from "convex/react";
import { api } from "../convex/_generated/api";
import Board from "./components/Board";
import Feed from "./components/Feed";
import Header from "./components/Header";

export default function App() {
  const projects = useQuery(api.projects.list);
  const project = projects?.[0];
  const jobs = useQuery(
    api.jobs.listByProject,
    project ? { projectId: project._id } : "skip"
  );
  const job = jobs?.[0];

  if (projects === undefined) return <Splash text="Loading" />;
  if (!project)
    return <Splash text="No project yet - run: npx convex run seed:demo" />;

  return (
    <div className="min-h-screen">
      <Header project={project} />
      <main className="mx-auto max-w-[1400px] px-6 py-8 grid grid-cols-1 xl:grid-cols-[1fr_320px] gap-8">
        <div>{job ? <Board jobId={job._id} /> : <Splash text="No job yet" />}</div>
        {project && <Feed projectId={project._id} />}
      </main>
    </div>
  );
}

function Splash({ text }) {
  return (
    <div className="min-h-screen grid place-items-center text-stone-400 text-sm">
      {text}
    </div>
  );
}
EOF

cat > src/components/Header.tsx << 'EOF'
import { useMutation } from "convex/react";
import { api } from "../../convex/_generated/api";

export default function Header({ project }) {
  const bump = useMutation(api.projects.bumpRevision);

  return (
    <header className="border-b border-stone-200 bg-white">
      <div className="mx-auto max-w-[1400px] px-6 py-4 flex items-center justify-between">
        <div className="flex items-baseline gap-4">
          <span className="text-xl font-bold tracking-tight">Bidzy</span>
          <span className="text-stone-300">/</span>
          <span className="text-sm text-stone-600">{project.name}</span>
          <span className="text-[11px] uppercase tracking-wide text-stone-400 border border-stone-200 rounded px-1.5 py-0.5">
            Design rev {project.revision}
          </span>
        </div>
        <button
          onClick={() =>
            bump({
              projectId: project._id,
              note: "Architect issued a design update - glazing spec changed",
            })
          }
          className="text-xs font-medium bg-stone-900 text-white px-3 py-2 rounded-md hover:bg-stone-700 transition"
        >
          Simulate design change
        </button>
      </div>
    </header>
  );
}
EOF

cat > src/components/Feed.tsx << 'EOF'
import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";

const DOT = {
  design_changed: "bg-amber-500",
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

cat > src/components/Board.tsx << 'EOF'
import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";

const money = (n) =>
  n == null ? "-" : "$" + n.toLocaleString(undefined, { maximumFractionDigits: 0 });

export default function Board({ jobId }) {
  const data = useQuery(api.jobs.board, { jobId });
  if (!data) return <p className="text-sm text-stone-400">Loading board...</p>;

  const { job, rows, allExclusions, lowest, quotedCount, invitedCount } = data;

  return (
    <section>
      <div className="flex items-end justify-between mb-6">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">{job.name}</h1>
          <p className="text-sm text-stone-500 mt-1">
            {quotedCount} of {invitedCount} firms have priced this job
          </p>
        </div>
      </div>

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
                  <div className="font-semibold text-stone-900">{r.firmName}</div>
                  <div className="flex items-center gap-1.5 mt-1.5 flex-wrap">
                    <Status status={r.status} />
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
                    className={`px-5 py-4 ${r.quote?.stale ? "opacity-35" : ""}`}
                  >
                    <div
                      className={`text-lg font-semibold tabular-nums ${
                        isLow ? "text-emerald-700" : "text-stone-900"
                      }`}
                    >
                      {money(r.quote?.total)}
                    </div>
                    {isLow && (
                      <div className="text-[10px] uppercase tracking-wide text-emerald-700 mt-0.5">
                        Lowest quoted
                      </div>
                    )}
                    {r.quote?.stale && (
                      <div className="text-[10px] text-amber-700 mt-1 leading-tight">
                        Priced against the old design
                      </div>
                    )}
                    {r.quote?.needsReview && (
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
                      className={`px-5 py-2.5 ${r.quote.stale ? "opacity-35" : ""}`}
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

function Status({ status }) {
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

echo ""
echo "All files written."
echo ""
echo "Next:"
echo "  1. npm install"
echo "  2. npx convex dev        (leave running in this tab)"
echo "  3. new tab: npx convex run seed:demo"
echo "  4. new tab: npm run dev"
