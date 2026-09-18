#!/bin/bash
# Declined companies read as declined; names get two lines.
set -e
[ -d convex/quoteEngine ] || { echo "Run from the bidzy project root."; exit 1; }

python3 - << 'PY'
p = "src/components/Board.tsx"
s = open(p).read()

# names may wrap to two lines; narrower label column at 5+ companies
s = s.replace(
  'const colW = `${Math.floor(76 / Math.max(rows.length, 1))}%`;',
  'const wide = rows.length > 4;\n  const labelW = wide ? 18 : 24;\n  const colW = `${Math.floor((100 - labelW) / Math.max(rows.length, 1))}%`;'
)
s = s.replace('<col style={{ width: "24%" }} />', '<col style={{ width: `${labelW}%` }} />')

# two-line name block, chips below
s = s.replace(
  '''                  <div
                    className={`h-5 text-[14px] font-semibold leading-5 truncate ${
                      r.quote?.stale ? "text-[#5A5A5A]" : "text-[#EDEDED]"
                    }`}
                  >
                    {r.firmName}
                  </div>''',
  '''                  <div
                    className={`h-10 text-[14px] font-semibold leading-5 ${
                      r.quote?.stale ? "text-[#5A5A5A]" : "text-[#EDEDED]"
                    }`}
                  >
                    {r.firmName}
                  </div>'''
)
s = s.replace('<div className="h-5" />', '<div className="h-10" />')

# a declined company says so, in every row
s = s.replace(
  '''function Status({ row }) {
  if (row.quote?.stale) return <Chip tone="warn">needs repricing</Chip>;
  if (row.quote) return <Chip tone="good">replied</Chip>;
  if (row.chaseCount > 0) return <Chip tone="neutral">chased {row.chaseCount}×</Chip>;
  return <Chip tone="neutral">no reply yet</Chip>;
}''',
  '''function Status({ row }) {
  if (row.status === "declined") return <Chip tone="neutral">not bidding</Chip>;
  if (row.quote?.stale) return <Chip tone="warn">needs repricing</Chip>;
  if (row.quote) return <Chip tone="good">replied</Chip>;
  if (row.chaseCount > 0) return <Chip tone="neutral">chased {row.chaseCount}×</Chip>;
  return <Chip tone="neutral">no reply yet</Chip>;
}

// A company that isn't bidding shouldn't look like one we're still waiting on.
function Blank({ row }) {
  return (
    <span className="text-[12.5px] text-[#4A4A4A]">
      {row.status === "declined" ? "not bidding" : "—"}
    </span>
  );
}'''
)

# use Blank wherever a quote is missing
s = s.replace(
  '''                  <span className="num text-[15px] text-[#A1A1A1] leading-6">
                    {money(r.quote?.total)}
                  </span>''',
  '''                  {r.quote ? (
                    <span className="num text-[15px] text-[#A1A1A1] leading-6">
                      {money(r.quote.total)}
                    </span>
                  ) : (
                    <Blank row={r} />
                  )}'''
)
s = s.replace(
  '''                    <span className="text-[#3A3A3A] leading-6">—</span>''',
  '''                    <Blank row={r} />'''
)
s = s.replace(
  '''                      <span
                        className={`num block text-[22px] font-bold tracking-tight leading-7 ${
                          best
                            ? "text-[#4ADE80]"
                            : r.quote?.stale
                            ? "text-[#5A5A5A] line-through"
                            : "text-[#EDEDED]"
                        }`}
                      >
                        {money(r.quote?.comparable)}
                      </span>''',
  '''                      {r.quote ? (
                        <span
                          className={`num block text-[22px] font-bold tracking-tight leading-7 ${
                            best
                              ? "text-[#4ADE80]"
                              : r.quote.stale
                              ? "text-[#5A5A5A] line-through"
                              : "text-[#EDEDED]"
                          }`}
                        >
                          {money(r.quote.comparable)}
                        </span>
                      ) : (
                        <span className="block text-[13px] leading-7 text-[#4A4A4A]">
                          {r.status === "declined" ? "not bidding" : "waiting"}
                        </span>
                      )}'''
)
s = s.replace(
  '''                      <td key={r.firmId} className="h-11 pl-5 text-[#3A3A3A] align-middle">
                        —
                      </td>''',
  '''                      <td key={r.firmId} className="h-11 pl-5 align-middle">
                        <span className="text-[12px] text-[#3A3A3A]">
                          {r.status === "declined" ? "" : "—"}
                        </span>
                      </td>'''
)
open(p, "w").write(s)
print("declined handled, names get two lines")
PY

# Stats should count who is actually still in the running
python3 - << 'PY'
p = "src/components/Stats.tsx"
s = open(p).read()
s = s.replace(
  '''        value={
          <>
            {d.quotedCount}
            <span className="text-[#5A5A5A]">/{d.invitedCount}</span>
          </>
        }''',
  '''        value={
          <>
            {d.quotedCount}
            <span className="text-[#5A5A5A]">/{d.invitedCount}</span>
          </>
        }
        foot={
          d.invitedCount - d.quotedCount > 0
            ? `${d.invitedCount - d.quotedCount} still out`
            : "everyone has answered"
        }'''
)
open(p, "w").write(s)
print("replies card notes who is outstanding")
PY

echo "done"
