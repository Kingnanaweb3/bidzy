#!/bin/bash
# Only an official register counts. A directory listing is not a licence.
set -e
[ -f convex/verify.ts ] || { echo "Run stage2 of bidzy-compliance.sh first."; exit 1; }

python3 - << 'PY'
p = "convex/verify.ts"
s = open(p).read()

s = s.replace(
'''const SCHEMA = {
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
};''',
'''const SCHEMA = {
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
    x.toLowerCase().replace(/[^a-z0-9 ]/g, " ").split(/\\s+/).filter(Boolean);
  const a = norm(wanted).filter((w) => !["roofing", "roof", "systems", "exteriors", "the", "llc", "inc", "group", "co"].includes(w));
  const b = new Set(norm(onPage));
  if (!a.length) return false;
  return a.every((w) => b.has(w));
}''')

s = s.replace(
'''    body: JSON.stringify({
      query: `"${name}" roofing contractor licence OR license register ${region}`,
      limit: 4,''',
'''    body: JSON.stringify({
      query: `"${name}" contractor license lookup state licensing board ${region}`,
      limit: 6,''')

s = s.replace(
'''  for (const r of results) {
    const j = r.json ?? {};
    if (j.found && j.status && j.status !== "not_found") {
      return { ...j, sourceUrl: r.url };
    }
  }
  return { found: false, status: "not_found", confident: false, sourceUrl: results[0]?.url };''',
'''  // Three things have to be true before we will claim anything: it is an
  // official register, it names this company, and it carries a record.
  for (const r of results) {
    const j = r.json ?? {};
    if (!j.isOfficialRegister) continue;
    if (!looksOfficial(r.url)) continue;
    if (!nameMatches(name, String(j.nameOnPage ?? ""))) continue;
    if (!j.found) continue;
    if (j.status !== "valid" && j.status !== "expired") continue;
    return { ...j, sourceUrl: r.url, confident: true };
  }

  // Anything else is "we could not check", which is honest and useful.
  // Saying "valid" on the strength of a directory listing would not be.
  return {
    found: false,
    status: "not_found",
    confident: false,
    evidence: "No official licensing register listed this company.",
    sourceUrl: undefined,
  };''')

open(p, "w").write(s)
print("verification now requires an official source")
PY

python3 - << 'PY'
p = "convex/verifyNotes.ts"
s = open(p).read()
s = s.replace(
'''    const summary =
      a.status === "expired"
        ? `${a.firmName}'s licence shows as expired on the public register`
        : a.status === "valid"
        ? `${a.firmName}'s licence checks out`
        : `No licence record found for ${a.firmName}`;''',
'''    const summary =
      a.status === "expired"
        ? `${a.firmName}'s licence shows as expired on the public register`
        : a.status === "valid"
        ? `${a.firmName}'s licence checks out on the public register`
        : `Couldn't verify ${a.firmName} — no official register listed them`;'''
)
open(p, "w").write(s)
print("wording no longer overstates a miss")
PY

# the UI should say "unverified", not imply a pass
python3 - << 'PY'
import pathlib
p = pathlib.Path("src/components/Board.tsx")
s = p.read_text()
s = s.replace(
    '''                    {r.licenceStatus === "not_found" && (
                      <Chip tone="neutral">no licence found</Chip>
                    )}''',
    '''                    {r.licenceStatus === "not_found" && (
                      <Chip tone="neutral">unverified</Chip>
                    )}'''
)
s = s.replace(
    '''                      <a
                        href={r.licence?.sourceUrl ?? undefined}''',
    '''                      <a
                        href={r.licence?.sourceUrl ?? undefined}'''
)
s = s.replace(
    '''                    {r.licenceStatus === "expired" && (''',
    '''                    {r.licenceStatus === "valid" && r.licence?.sourceUrl && (
                      <a
                        href={r.licence.sourceUrl}
                        target="_blank"
                        rel="noreferrer"
                        title={r.licence.evidence ?? "Licence verified"}
                      >
                        <Chip tone="good">licence checked</Chip>
                      </a>
                    )}
                    {r.licenceStatus === "expired" && ('''
)
p.write_text(s)

p = pathlib.Path("src/components/BoardMobile.tsx")
s = p.read_text()
s = s.replace(
    '''                  {r.licenceStatus === "not_found" && (
                    <Chip tone="neutral">no licence</Chip>
                  )}''',
    '''                  {r.licenceStatus === "not_found" && (
                    <Chip tone="neutral">unverified</Chip>
                  )}'''
)
p.write_text(s)
print("badges say what they mean")
PY

echo ""
echo "Then: npx convex dev --once && npx convex run verify:checkAll '{\"jobId\":\"...\"}'"
