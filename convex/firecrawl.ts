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
