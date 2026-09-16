#!/bin/bash
# Firecrawl: read a contractor's quote PDF into a structured quote.
set -e
[ -d convex/quoteEngine ] || { echo "Run from the bidzy project root."; exit 1; }

echo "Wiring Firecrawl..."

cat > convex/firecrawl.ts << 'EOF'
import { action, internalAction } from "./_generated/server";
import { internal, api, components } from "./_generated/api";
import { v } from "convex/values";

const BASE = "https://api.firecrawl.dev/v2";

function key() {
  const k = process.env.FIRECRAWL_API_KEY;
  if (!k) throw new Error("FIRECRAWL_API_KEY is not set on this deployment");
  return k;
}

// What we want out of a contractor's quote, whatever shape it arrived in.
const QUOTE_SCHEMA = {
  type: "object",
  properties: {
    company: { type: "string", description: "The company issuing the quote" },
    total: {
      type: "number",
      description: "The total price as a number, no currency symbol",
    },
    lineItems: {
      type: "array",
      description: "Each priced item of work",
      items: {
        type: "object",
        properties: {
          label: { type: "string" },
          amount: { type: "number" },
        },
      },
    },
    inclusions: {
      type: "array",
      description:
        "Work or costs explicitly stated as included in the price, e.g. delivery, sales tax, removal and disposal, skip hire",
      items: { type: "string" },
    },
    exclusions: {
      type: "array",
      description:
        "Work or costs explicitly stated as NOT included, excluded, or the customer's responsibility",
      items: { type: "string" },
    },
    material: {
      type: "string",
      description:
        "The main material being priced, e.g. asphalt shingle, slate, tile",
    },
  },
  required: ["total"],
};

async function scrapeDocument(url: string) {
  const res = await fetch(`${BASE}/scrape`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key()}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      url,
      formats: [
        "markdown",
        { type: "json", schema: QUOTE_SCHEMA },
      ],
      // make sure PDFs go through Fire-PDF rather than being treated as html
      parsers: [{ type: "pdf", mode: "auto" }],
      onlyMainContent: false,
    }),
  });

  const body = await res.text();
  if (!res.ok) throw new Error(`Firecrawl ${res.status}: ${body.slice(0, 400)}`);
  const parsed = JSON.parse(body);
  return parsed.data ?? parsed;
}

// Turn Firecrawl's structured output into a quote the component understands.
function toQuote(data: any) {
  const j = data.json ?? {};
  const markdown: string = data.markdown ?? "";

  const lineItems = Array.isArray(j.lineItems)
    ? j.lineItems
        .filter((li: any) => li && li.label)
        .map((li: any) => ({
          label: String(li.label).slice(0, 120),
          amount: typeof li.amount === "number" ? li.amount : undefined,
        }))
    : [];

  const clean = (arr: any) =>
    Array.isArray(arr)
      ? [...new Set(arr.filter(Boolean).map((s: any) => title(String(s))))]
      : [];

  const material = String(j.material ?? "").toLowerCase();
  const scopeTags: string[] = [];
  if (material.includes("slate")) scopeTags.push("slate");
  if (material.includes("asphalt") || material.includes("shingle"))
    scopeTags.push("asphalt-shingle");
  if (scopeTags.length === 0) scopeTags.push("asphalt-shingle");

  const total = typeof j.total === "number" ? j.total : undefined;

  return {
    total,
    lineItems,
    inclusions: clean(j.inclusions),
    exclusions: clean(j.exclusions),
    scopeTags,
    // if Firecrawl couldn't find a total, or named nothing excluded,
    // a human should look before this number is trusted
    needsReview: total == null || clean(j.exclusions).length === 0,
    rawText: markdown.slice(0, 4000),
  };
}

function title(s: string) {
  const t = s.trim().replace(/\.$/, "");
  return t.charAt(0).toUpperCase() + t.slice(1);
}

// Called from the UI: point at a quote document and read it.
export const readQuoteDocument = action({
  args: {
    jobId: v.id("jobs"),
    firmId: v.id("firms"),
    url: v.string(),
  },
  handler: async (ctx, { jobId, firmId, url }) => {
    const data = await scrapeDocument(url);
    const quote = toQuote(data);

    await ctx.runMutation(api.quotes.record, {
      jobId,
      firmId,
      total: quote.total,
      lineItems: quote.lineItems,
      inclusions: quote.inclusions,
      exclusions: quote.exclusions,
      scopeTags: quote.scopeTags,
      needsReview: quote.needsReview,
      rawText: quote.rawText,
      sourceUrl: url,
    });

    return {
      total: quote.total,
      exclusions: quote.exclusions,
      inclusions: quote.inclusions,
      lineItems: quote.lineItems.length,
      needsReview: quote.needsReview,
    };
  },
});

// Called automatically when a contractor emails a PDF.
export const readAttachment = internalAction({
  args: {
    jobId: v.id("jobs"),
    firmId: v.id("firms"),
    url: v.string(),
    filename: v.string(),
  },
  handler: async (ctx, { jobId, firmId, url, filename }) => {
    try {
      const data = await scrapeDocument(url);
      const quote = toQuote(data);

      await ctx.runMutation(api.quotes.record, {
        jobId,
        firmId,
        total: quote.total,
        lineItems: quote.lineItems,
        inclusions: quote.inclusions,
        exclusions: quote.exclusions,
        scopeTags: quote.scopeTags,
        needsReview: quote.needsReview,
        rawText: quote.rawText,
        sourceUrl: url,
      });

      await ctx.runMutation(internal.mail.noteAttachmentRead, {
        jobId,
        filename,
        total: quote.total,
        exclusionCount: quote.exclusions.length,
      });
    } catch (e: any) {
      await ctx.runMutation(internal.mail.noteAttachmentFailed, {
        jobId,
        filename,
        reason: String(e.message ?? e).slice(0, 200),
      });
    }
  },
});
EOF

# ---------- mail: schedule the parse when a PDF arrives ----------
python3 - << 'PY'
p = "convex/mail.ts"
s = open(p).read()

# add the two note mutations
s = s.replace(
  "export const recordOutbound = internalMutation({",
  '''export const noteAttachmentRead = internalMutation({
  args: {
    jobId: v.id("jobs"),
    filename: v.string(),
    total: v.optional(v.number()),
    exclusionCount: v.number(),
  },
  handler: async (ctx, { jobId, filename, total, exclusionCount }) => {
    const job = await ctx.db.get(jobId);
    if (!job) return;
    await ctx.db.insert("events", {
      projectId: job.projectId,
      jobId,
      type: "quote_parsed",
      summary: `Read ${filename}${
        total != null ? ` - $${total.toLocaleString()}` : ""
      }${exclusionCount ? `, ${exclusionCount} thing${
        exclusionCount === 1 ? "" : "s"
      } not covered` : ""}`,
      createdAt: Date.now(),
    });
  },
});

export const noteAttachmentFailed = internalMutation({
  args: { jobId: v.id("jobs"), filename: v.string(), reason: v.string() },
  handler: async (ctx, { jobId, filename, reason }) => {
    const job = await ctx.db.get(jobId);
    if (!job) return;
    await ctx.db.insert("events", {
      projectId: job.projectId,
      jobId,
      type: "parse_failed",
      summary: `Couldn't read ${filename} - ${reason}`,
      createdAt: Date.now(),
    });
  },
});

export const recordOutbound = internalMutation({'''
)

# schedule parsing of PDF attachments on inbound mail
s = s.replace(
  "    if (!firm) return { stored: true, matched: false };",
  '''    // A PDF attachment is the real quote. Hand it to Firecrawl.
    const pdfs = (args.attachments ?? []).filter(
      (a) =>
        a.url &&
        (a.filename.toLowerCase().endsWith(".pdf") ||
          (a.contentType ?? "").includes("pdf"))
    );
    if (firm && pdfs.length) {
      for (const pdf of pdfs) {
        await ctx.scheduler.runAfter(0, internal.firecrawl.readAttachment, {
          jobId,
          firmId: firm._id,
          url: pdf.url,
          filename: pdf.filename,
        });
      }
      return { stored: true, matched: true, queued: pdfs.length };
    }

    if (!firm) return { stored: true, matched: false };'''
)
open(p, "w").write(s)
print("mail.ts wired to firecrawl")
PY

# ---------- UI: read a document ----------
cat > src/components/ReadDoc.tsx << 'EOF'
import { useState } from "react";
import { useAction, useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";

export default function ReadDoc({ jobId, rows }) {
  const read = useAction(api.firecrawl.readQuoteDocument);
  const [url, setUrl] = useState("");
  const [firmId, setFirmId] = useState(rows?.[0]?.firmId ?? "");
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState("");
  const [err, setErr] = useState("");

  const go = async () => {
    if (!url || !firmId) return;
    setBusy(true);
    setErr("");
    setMsg("");
    try {
      const r = await read({ jobId, firmId, url });
      setMsg(
        `Read ${r.total != null ? "$" + r.total.toLocaleString() : "no total"}` +
          (r.exclusions.length
            ? ` - not covered: ${r.exclusions.join(", ")}`
            : "") +
          (r.needsReview ? " (flagged for review)" : "")
      );
      setUrl("");
    } catch (e) {
      setErr(String(e.message ?? e));
    }
    setBusy(false);
  };

  return (
    <section className="mt-10">
      <h2 className="text-[11px] uppercase tracking-widest text-stone-400 mb-1">
        Read a quote document
      </h2>
      <p className="text-xs text-stone-500 mb-4">
        Paste the link to a PDF quote. Emailed PDFs are read automatically.
      </p>

      <div className="flex gap-2 flex-wrap">
        <select
          value={firmId}
          onChange={(e) => setFirmId(e.target.value)}
          className="text-sm border border-stone-300 rounded-md px-3 py-2 bg-white"
        >
          {rows?.map((r) => (
            <option key={r.firmId} value={r.firmId}>
              {r.firmName}
            </option>
          ))}
        </select>
        <input
          value={url}
          onChange={(e) => setUrl(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && go()}
          placeholder="https://.../quote.pdf"
          className="flex-1 min-w-[280px] text-sm border border-stone-300 rounded-md px-3 py-2"
        />
        <button
          onClick={go}
          disabled={busy || !url}
          className="text-xs font-medium bg-stone-900 text-white px-4 py-2 rounded-md hover:bg-stone-700 disabled:bg-stone-200 disabled:text-stone-400"
        >
          {busy ? "Reading..." : "Read it"}
        </button>
      </div>

      {msg && (
        <p className="mt-3 text-sm text-emerald-800 bg-emerald-50 border border-emerald-200 rounded-md px-3 py-2">
          {msg}
        </p>
      )}
      {err && (
        <p className="mt-3 text-xs text-red-700 bg-red-50 border border-red-200 rounded-md px-3 py-2">
          {err}
        </p>
      )}
    </section>
  );
}
EOF

python3 - << 'PY'
p = "src/App.tsx"
s = open(p).read()
s = s.replace(
  'import Inbox from "./components/Inbox";',
  'import Inbox from "./components/Inbox";\nimport ReadDoc from "./components/ReadDoc";'
)
s = s.replace(
  "import Board from \"./components/Board\";",
  "import Board from \"./components/Board\";"
)
s = s.replace(
  "              <Board jobId={job._id} />\n              <Inbox job={job} jobId={job._id} />",
  "              <Board jobId={job._id} />\n              <Docs jobId={job._id} />\n              <Inbox job={job} jobId={job._id} />"
)
s = s.replace(
  "function Splash({ text }) {",
  '''function Docs({ jobId }) {
  const data = useQuery(api.jobs.board, { jobId });
  if (!data) return null;
  return <ReadDoc jobId={jobId} rows={data.rows} />;
}

function Splash({ text }) {'''
)
open(p, "w").write(s)
print("App.tsx wired")
PY

echo ""
echo "Done. Set the key, then redeploy:"
echo "  npx convex env set FIRECRAWL_API_KEY 'fc-...'"
echo "  npx convex env set --prod FIRECRAWL_API_KEY 'fc-...'"
