#!/bin/bash
# Fix 1: collapse equivalent exclusion labels ("Removal and disposal" vs
#        "Removal and disposal of the existing roof") into one row.
# Fix 2: make the read panel say which company it read for.
set -e
[ -d convex/quoteEngine ] || { echo "Run from the bidzy project root."; exit 1; }

python3 - << 'PY'
p = "convex/quoteEngine/quotes.ts"
s = open(p).read()

# --- add canonical label handling ---
s = s.replace(
'''const lineItem = v.object({''',
'''// Contractors describe the same item a dozen ways. The component decides
// what counts as the same thing, so the board has one row per real item.
const CANONICAL: Array<[string, string[]]> = [
  ["Removal and disposal", ["removal", "disposal", "tear-off", "tear off", "strip"]],
  ["Delivery", ["delivery", "deliver", "transport", "haulage"]],
  ["Skip hire", ["skip", "dumpster", "waste container"]],
  ["Crane hire", ["crane", "craneage", "hoist"]],
  ["Sales tax", ["sales tax", "tax", "vat"]],
  ["Night work", ["night work", "out of hours", "overtime"]],
  ["Gutter replacement", ["gutter", "guttering", "downpipe"]],
  ["Temporary protection", ["temporary protection", "sheeting", "scaffold cover"]],
  ["Scaffolding", ["scaffold"]],
  ["Structural repair", ["structural", "rafter", "joist", "decking repair"]],
  ["Permits", ["permit", "building control", "planning"]],
  ["Warranty", ["warranty", "guarantee"]],
];

export function canonical(raw: string): string {
  const t = raw.toLowerCase();
  for (const [label, needles] of CANONICAL) {
    if (needles.some((n) => t.includes(n))) return label;
  }
  // nothing matched - keep it, but tidied
  const clean = raw.trim().replace(/\\.$/, "");
  return clean.charAt(0).toUpperCase() + clean.slice(1);
}

function canonicalList(arr?: string[]): string[] {
  return [...new Set((arr ?? []).filter(Boolean).map(canonical))];
}

const lineItem = v.object({'''
)

# apply canonicalisation on write
s = s.replace(
'''      inclusions: args.inclusions ?? [],
      exclusions: args.exclusions ?? [],''',
'''      inclusions: canonicalList(args.inclusions),
      exclusions: canonicalList(args.exclusions),'''
)

# and on confirm
s = s.replace(
'''    const clean = Object.fromEntries(
      Object.entries(patch).filter(([, val]) => val !== undefined)
    );''',
'''    const clean: any = Object.fromEntries(
      Object.entries(patch).filter(([, val]) => val !== undefined)
    );
    if (clean.exclusions) clean.exclusions = canonicalList(clean.exclusions);'''
)

# benchmark matching uses canonical labels on both sides now
s = s.replace(
'''      for (const label of q.inclusions) {
        if (!matches(item.label, label)) continue;''',
'''      for (const label of q.inclusions) {
        if (!matches(item.label, label) && canonical(item.label) !== label)
          continue;'''
)

open(p, "w").write(s)
print("quoteEngine: canonical labels in")
PY

# one-off: tidy labels already stored
cat > convex/tidy.ts << 'EOF'
import { mutation } from "./_generated/server";
import { components } from "./_generated/api";

// Re-writes existing quotes through the component so older rows pick up
// canonical exclusion labels.
export const labels = mutation({
  args: {},
  handler: async (ctx) => {
    const jobs = await ctx.db.query("jobs").collect();
    let touched = 0;
    for (const job of jobs) {
      const quotes = await ctx.runQuery(
        components.quoteEngine.quotes.listByJob,
        { jobKey: String(job._id) }
      );
      for (const q of quotes) {
        await ctx.runMutation(components.quoteEngine.quotes.record, {
          jobKey: String(job._id),
          partyKey: q.partyKey,
          partyName: q.partyName,
          total: q.total,
          lineItems: q.lineItems,
          inclusions: q.inclusions,
          exclusions: q.exclusions,
          scopeTags: q.scopeTags,
          needsReview: q.needsReview,
          rawText: q.rawText,
          sourceUrl: q.sourceUrl,
        });
        touched++;
      }
    }
    return { touched };
  },
});
EOF

# --- fix 2: the read panel names the company ---
python3 - << 'PY'
p = "src/components/ReadDoc.tsx"
s = open(p).read()

s = s.replace(
'''      const r = await read({ jobId, firmId, url });
      setMsg(
        `Read ${r.total != null ? "$" + r.total.toLocaleString() : "no total"}` +''',
'''      const name = rows.find((x) => x.firmId === firmId)?.firmName ?? "that company";
      const r = await read({ jobId, firmId, url });
      setMsg(
        `${name}: read ${r.total != null ? "$" + r.total.toLocaleString() : "no total"}` +'''
)

s = s.replace(
'''        <select
          value={firmId}
          onChange={(e) => setFirmId(e.target.value)}
          className="text-sm border border-stone-300 rounded-md px-3 py-2 bg-white"
        >''',
'''        <select
          value={firmId}
          onChange={(e) => setFirmId(e.target.value)}
          className="text-sm border-2 border-stone-400 rounded-md px-3 py-2 bg-white font-medium"
        >'''
)

s = s.replace(
  'Paste the link to a PDF quote. Emailed PDFs are read automatically.',
  'Choose who sent it, then paste the link. Emailed PDFs are read automatically.'
)
open(p, "w").write(s)
print("ReadDoc: names the company")
PY

echo ""
echo "Done. Then:"
echo "  npx convex dev --once && npx convex run tidy:labels"
