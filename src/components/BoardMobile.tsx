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
                <p className="display text-[13px] font-semibold leading-4">
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
