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
    isOfficialRegister: {
      type: "boolean",
      description:
        "True ONLY if this page is a government or state licensing board record — a contractor licence lookup, a state board register, a municipal permit database. A business directory, review site, marketing page, video, or aggregator like BBB, BuildZoom, Angi, Yelp, GAF or Houzz is NOT an official register.",
    },
    nameOnPage: {
      type: "string",
      description: "The company name exactly as it appears on this page",
    },
    found: {
      type: "boolean",
      description: "True only if a licence record for this exact company is on this page",
    },
    status: {
      type: "string",
      description:
        "One of: valid, expired, not_found. Use expired if the record shows lapsed, suspended, revoked, or an expiry date in the past. Use not_found if no licence record is present.",
    },
    licenceNumber: { type: "string" },
    expiresOn: { type: "string", description: "Expiry date exactly as written on the register" },
    registryName: { type: "string", description: "The government body publishing the record" },
    evidence: {
      type: "string",
      description: "The sentence on the page supporting this, quoted, under 25 words",
    },
  },
  required: ["isOfficialRegister", "found", "status"],
};

// A page that isn't a register tells us nothing, whatever it says.
const NOT_A_REGISTER = [
  "bbb.org", "buildzoom", "angi.com", "angieslist", "yelp", "houzz",
  "gaf.com", "owenscorning", "youtube", "facebook", "linkedin",
  "thumbtack", "porch.com", "homeadvisor", "nextdoor", "yellowpages",
];

function looksOfficial(url: string) {
  const u = (url ?? "").toLowerCase();
  if (NOT_A_REGISTER.some((d) => u.includes(d))) return false;
  return (
    u.includes(".gov") ||
    u.includes("licen") ||
    u.includes("register") ||
    u.includes("board") ||
    u.includes("permit")
  );
}

// "Apex Roofing" and "Apex Roofing & Solar" are plausibly the same firm.
// "Apex Roofing" and "All Phase Construction" are not.
function nameMatches(wanted: string, onPage: string) {
  if (!onPage) return false;
  const norm = (x: string) =>
    x.toLowerCase().replace(/[^a-z0-9 ]/g, " ").split(/\s+/).filter(Boolean);
  const a = norm(wanted).filter((w) => !["roofing", "roof", "systems", "exteriors", "the", "llc", "inc", "group", "co"].includes(w));
  const b = new Set(norm(onPage));
  if (!a.length) return false;
  return a.every((w) => b.has(w));
}

// NYC publishes its home improvement contractor register at a URL you can
// query. So rather than searching the open web and hoping a government page
// comes back, Bidzy asks the register itself.
const REGISTER = {
  name: "NYC Department of Consumer and Worker Protection",
  url: (q: string) =>
    `https://a866-dcwpbp.nyc.gov/search?query=${encodeURIComponent(q)}`,
};

const RESULTS_SCHEMA = {
  type: "object",
  properties: {
    matches: {
      type: "array",
      description: "Every business listed in the search results on this page",
      items: {
        type: "object",
        properties: {
          businessName: { type: "string" },
          address: { type: "string" },
          status: {
            type: "string",
            description:
              "The licence status badge shown beside this business, exactly as written: Licensed, Not Licensed, Inactive, Expired, Revoked",
          },
        },
      },
    },
  },
  required: ["matches"],
};

function tokens(x: string) {
  return x
    .toLowerCase()
    .replace(/[^a-z0-9 ]/g, " ")
    .split(/\s+/)
    .filter(Boolean)
    .filter(
      (w) =>
        ![
          "roofing", "roof", "systems", "exteriors", "construction", "contracting",
          "contractors", "corp", "inc", "llc", "ltd", "co", "group", "the", "and",
        ].includes(w)
    );
}

// The register returns everything containing the word. Only a real overlap
// of distinctive words counts as the same company.
function scoreMatch(wanted: string, candidate: string) {
  const a = tokens(wanted);
  const b = new Set(tokens(candidate));
  if (!a.length) return 0;
  const hit = a.filter((w) => b.has(w)).length;
  return hit / a.length;
}

function readStatus(raw: string) {
  const t = (raw ?? "").toLowerCase();
  if (t.includes("not licensed") || t.includes("revoked")) return "expired";
  if (t.includes("inactive") || t.includes("expired") || t.includes("lapsed"))
    return "expired";
  if (t.includes("licensed") || t.includes("active")) return "valid";
  return "unknown";
}

async function lookUp(name: string, _region: string) {
  const key = process.env.FIRECRAWL_API_KEY;
  if (!key) throw new Error("FIRECRAWL_API_KEY is not set");

  const first = tokens(name)[0] ?? name;
  const url = REGISTER.url(first);

  const res = await fetch("https://api.firecrawl.dev/v2/scrape", {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      url,
      formats: ["markdown", { type: "json", schema: RESULTS_SCHEMA }],
      waitFor: 2500,
      onlyMainContent: false,
    }),
  });

  const body = await res.text();
  if (!res.ok) throw new Error(`Firecrawl ${res.status}: ${body.slice(0, 300)}`);
  const parsed = JSON.parse(body);
  const data = parsed.data ?? parsed;
  const matches = data.json?.matches ?? [];

  let best: any = null;
  let bestScore = 0;
  for (const m of matches) {
    const score = scoreMatch(name, String(m.businessName ?? ""));
    if (score > bestScore) {
      bestScore = score;
      best = m;
    }
  }

  // A partial name overlap is not the same company. Say so.
  // One shared word is not a match. Two distinctive words, or nothing.
  if (!best || bestScore < 0.6 || tokens(name).length < 2) {
    return {
      found: false,
      status: "not_found",
      confident: false,
      registryName: REGISTER.name,
      evidence: `The register lists ${matches.length} business${
        matches.length === 1 ? "" : "es"
      } matching "${first}", none of them this company.`,
      sourceUrl: url,
    };
  }

  const status = readStatus(String(best.status ?? ""));
  return {
    found: true,
    status,
    registryName: REGISTER.name,
    evidence: `${best.businessName} — ${best.status}${
      best.address ? `, ${best.address}` : ""
    }`,
    sourceUrl: url,
    confident: bestScore >= 0.8,
  };
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
