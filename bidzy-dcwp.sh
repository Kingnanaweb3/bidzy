#!/bin/bash
# Query the city's own licence register directly instead of guessing
# through a web search.
set -e
[ -f convex/verify.ts ] || { echo "Run bidzy-compliance.sh stage2 first."; exit 1; }

python3 - << 'PY'
p = "convex/verify.ts"
s = open(p).read()

start = s.index("async function lookUp(")
end = s.index("export const checkOne")
new = '''// NYC publishes its home improvement contractor register at a URL you can
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
    .split(/\\s+/)
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
  if (!best || bestScore < 0.6) {
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

'''
s = s[:start] + new + s[end:]
open(p, "w").write(s)
print("verification now queries the NYC register directly")
PY

echo ""
echo "Then:"
echo "  npx convex dev --once"
echo "  npx convex run verify:checkAll '{\"jobId\":\"jh776d7ddrp9txnvwa8j4sbdan8enn35\"}'"
