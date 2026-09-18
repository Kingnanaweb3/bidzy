#!/bin/bash
# On a phone the comparison becomes stacked cards, ranked cheapest first.
set -e
[ -d convex/quoteEngine ] || { echo "Run from the bidzy project root."; exit 1; }

cat > src/components/BoardMobile.tsx << 'EOF'
import { Chip, money } from "./ui";

// A table you have to scroll sideways isn't a comparison. On a narrow
// screen the same numbers become one card per company, cheapest first,
// each carrying its own arithmetic.
export default function BoardMobile({ d }) {
  const { rows, lowest } = d;

  const ranked = [...rows].sort((a, b) => {
    const av = a.quote?.comparable, bv = b.quote?.comparable;
    if (av == null && bv == null) return 0;
    if (av == null) return 1;
    if (bv == null) return -1;
    if (a.quote.stale !== b.quote.stale) return a.quote.stale ? 1 : -1;
    return av - bv;
  });

  return (
    <div className="p-4 space-y-3">
      {ranked.map((r) => {
        const q = r.quote;
        const best = q?.comparable != null && q.comparable === lowest && !q.stale;

        return (
          <div
            key={r.firmId}
            className={`rounded-xl border p-4 ${
              best
                ? "bg-[#0F2C1F] border-[#1B4A33]"
                : "bg-[#242424] border-[#2E2E2E]"
            } ${q?.stale ? "opacity-50" : ""}`}
          >
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0">
                <p className="text-[13px] font-semibold leading-4">
                  {r.firmName}
                </p>
                <div className="flex flex-wrap items-center gap-1.5 mt-2">
                  <Status row={r} />
                  {r.licenceStatus === "expired" && (
                    <Chip tone="bad">expired</Chip>
                  )}
                </div>
              </div>

              <div className="text-right shrink-0">
                {q ? (
                  <>
                    <p
                      className={`num text-[19px] font-bold leading-6 ${
                        best
                          ? "text-[#4ADE80]"
                          : q.stale
                          ? "text-[#5A5A5A] line-through"
                          : "text-[#EDEDED]"
                      }`}
                    >
                      {money(q.comparable)}
                    </p>
                    <p className="text-[10px] text-[#5A5A5A] leading-3 mt-0.5">
                      real cost
                    </p>
                  </>
                ) : (
                  <p className="text-[11px] text-[#4A4A4A] leading-6">
                    {r.status === "declined" ? "not bidding" : "waiting"}
                  </p>
                )}
              </div>
            </div>

            {q && (
              <>
                <div className="mt-3 pt-3 border-t border-[#2E2E2E] space-y-1.5">
                  <Row label="They quoted" value={money(q.total)} />
                  {q.hidden > 0 ? (
                    <Row
                      label="Work left out"
                      value={`+ ${money(q.hidden)}`}
                      tone="text-[#FBBF24]"
                    />
                  ) : (
                    <Row label="Work left out" value="nothing" tone="text-[#5A5A5A]" />
                  )}
                </div>

                {q.hidden > 0 && (
                  <p className="text-[10.5px] text-[#5A5A5A] leading-4 mt-2">
                    {q.gaps.map((g) => g.label).join(", ")}
                  </p>
                )}

                {best && (
                  <p className="text-[10.5px] text-[#4ADE80] leading-4 mt-2.5">
                    Cheapest once compared fairly
                  </p>
                )}
                {q.stale && (
                  <p className="text-[10.5px] text-[#FBBF24] leading-4 mt-2.5">
                    Priced the old job
                  </p>
                )}
                {q.needsReview && !q.stale && !best && (
                  <p className="text-[10.5px] text-[#60A5FA] leading-4 mt-2.5">
                    Worth checking by hand
                  </p>
                )}

                {q.exclusions.length > 0 && (
                  <details className="mt-3 group">
                    <summary className="text-[11px] text-[#A1A1A1] cursor-pointer list-none flex items-center gap-1.5">
                      <span className="group-open:rotate-90 transition-transform">›</span>
                      What this price does not cover
                    </summary>
                    <ul className="mt-2 space-y-1">
                      {q.exclusions.map((ex) => (
                        <li key={ex} className="text-[11px] text-[#F87171] leading-4">
                          {ex}
                        </li>
                      ))}
                    </ul>
                  </details>
                )}
              </>
            )}
          </div>
        );
      })}
    </div>
  );
}

function Row({ label, value, tone = "text-[#C9C9C9]" }) {
  return (
    <div className="flex items-center justify-between gap-3">
      <span className="text-[11.5px] text-[#A1A1A1]">{label}</span>
      <span className={`num text-[12.5px] ${tone}`}>{value}</span>
    </div>
  );
}

function Status({ row }) {
  if (row.status === "declined") return <Chip tone="neutral">not bidding</Chip>;
  if (row.quote?.stale) return <Chip tone="warn">needs repricing</Chip>;
  if (row.quote) return <Chip tone="good">replied</Chip>;
  if (row.chaseCount > 0) return <Chip tone="neutral">chased {row.chaseCount}×</Chip>;
  return <Chip tone="neutral">no reply yet</Chip>;
}
EOF

python3 - << 'PY'
p = "src/components/Board.tsx"
s = open(p).read()

s = s.replace(
  'import { Card, CardHead, Chip, I, money } from "./ui";',
  'import { Card, CardHead, Chip, I, money } from "./ui";\nimport BoardMobile from "./BoardMobile";'
)

# the wide table is desktop only
s = s.replace(
  '<div className="overflow-x-auto p-4 sm:p-6">',
  '<div className="hidden md:block overflow-x-auto p-4 sm:p-6">'
)

# stacked cards take over below md
s = s.replace(
  "      </div>\n    </Card>\n  );\n}\n\nfunction Line(",
  "      </div>\n\n      <div className=\"md:hidden\">\n        <BoardMobile d={d} />\n      </div>\n    </Card>\n  );\n}\n\nfunction Line("
)

# the banner reads tighter on a phone
s = s.replace(
  'className="text-[13.5px] text-[#FBBF24] leading-6"',
  'className="text-[12.5px] sm:text-[13.5px] text-[#FBBF24] leading-5 sm:leading-6"'
)
open(p, "w").write(s)
print("board switches layout at md")
PY

# ---- typography and chrome scale down ----
python3 - << 'PY'
import pathlib

edits = {
  "src/components/ui.tsx": [
    ('export const HEAD_H = "h-[64px]";', 'export const HEAD_H = "min-h-[58px] sm:min-h-[64px] py-3 sm:py-0";'),
    ('<h2 className="text-[14px] font-semibold leading-5">{title}</h2>',
     '<h2 className="text-[13px] sm:text-[14px] font-semibold leading-5">{title}</h2>'),
    ('className="text-[12px] text-[#5A5A5A] leading-4 mt-0.5 truncate"',
     'className="text-[11px] sm:text-[12px] text-[#5A5A5A] leading-4 mt-0.5 truncate"'),
    ('className="h-9 w-9 rounded-xl bg-[#2A2A2A] grid place-items-center text-[#A1A1A1] shrink-0"',
     'className="h-8 w-8 sm:h-9 sm:w-9 rounded-xl bg-[#2A2A2A] grid place-items-center text-[#A1A1A1] shrink-0"'),
    ('className="h-10 px-4 rounded-xl text-[13px] font-semibold bg-[#2F7FFF] text-white',
     'className="h-9 sm:h-10 px-3.5 sm:px-4 rounded-xl text-[12.5px] sm:text-[13px] font-semibold bg-[#2F7FFF] text-white'),
    ('className="h-10 px-4 rounded-xl text-[13px] font-medium bg-[#242424] text-[#C9C9C9]',
     'className="h-9 sm:h-10 px-3.5 sm:px-4 rounded-xl text-[12.5px] sm:text-[13px] font-medium bg-[#242424] text-[#C9C9C9]'),
  ],
  "src/components/Stats.tsx": [
    ('className="num text-[26px] sm:text-[30px] font-bold tracking-tight leading-9',
     'className="num text-[24px] sm:text-[30px] font-bold tracking-tight leading-8 sm:leading-9'),
    ('<span className="text-[13.5px] font-semibold">{label}</span>',
     '<span className="text-[12.5px] sm:text-[13.5px] font-semibold">{label}</span>'),
    ('className="h-[18px] text-[12.5px] text-[#A1A1A1] truncate"',
     'className="h-[18px] text-[11.5px] sm:text-[12.5px] text-[#A1A1A1] truncate"'),
  ],
  "src/components/Feed.tsx": [
    ('className="text-[12.5px] text-[#C9C9C9] leading-5"',
     'className="text-[12px] sm:text-[12.5px] text-[#C9C9C9] leading-5"'),
  ],
  "src/pages/BudgetPage.tsx": [
    ('className="text-[13px] text-[#A1A1A1] truncate"',
     'className="text-[12px] sm:text-[13px] text-[#A1A1A1] truncate"'),
    ('className="num text-[13px] text-[#C9C9C9] shrink-0"',
     'className="num text-[12px] sm:text-[13px] text-[#C9C9C9] shrink-0"'),
  ],
  "src/pages/DocsPage.tsx": [
    ('className="text-[12.5px] text-[#A1A1A1] truncate"',
     'className="text-[11.5px] sm:text-[12.5px] text-[#A1A1A1] truncate"'),
    ('className="num text-[12.5px] text-[#C9C9C9] shrink-0"',
     'className="num text-[11.5px] sm:text-[12.5px] text-[#C9C9C9] shrink-0"'),
  ],
  "src/pages/InboxPage.tsx": [
    ('className="text-[13px] font-medium truncate"',
     'className="text-[12.5px] sm:text-[13px] font-medium truncate"'),
    ('className="px-6 py-6 text-[13px] text-[#C9C9C9] leading-6 whitespace-pre-wrap font-sans"',
     'className="px-4 sm:px-6 py-5 sm:py-6 text-[12px] sm:text-[13px] text-[#C9C9C9] leading-5 sm:leading-6 whitespace-pre-wrap font-sans break-words"'),
  ],
}

for path, pairs in edits.items():
    f = pathlib.Path(path)
    if not f.exists():
        continue
    t = f.read_text()
    for a, b in pairs:
        t = t.replace(a, b)
    f.write_text(t)
print("type scaled for small screens")
PY

# ---- the inbox header buttons stop crowding on a phone ----
python3 - << 'PY'
p = "src/pages/InboxPage.tsx"
s = open(p).read()
s = s.replace(
  '<div className="flex flex-wrap gap-2">',
  '<div className="flex flex-wrap gap-2 w-full sm:w-auto">'
)
open(p, "w").write(s)
print("inbox actions wrap")
PY

echo "mobile done"
