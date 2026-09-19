import { Chip, Meta, ago, money } from "./ui";

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
    <div className="p-4 sm:p-5 grid gap-3 sm:gap-4 sm:grid-cols-2">
      {ranked.map((r) => {
        const q = r.quote;
        const best = q?.comparable != null && q.comparable === lowest && !q.stale;

        return (
          <div
            key={r.firmId}
            className={`rounded-xl border p-4 ${
              best
                ? "bg-[#0F2C1F] border-[#1B4A33]"
                : "bg-[#1C1C1A] border-[#262624]"
            } ${q?.stale ? "opacity-50" : ""}`}
          >
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0">
                <p className="display text-[length:var(--step-0)] font-semibold leading-4">
                  {r.firmName}
                </p>
                <div className="flex flex-wrap items-center gap-1.5 mt-2">
                  <Status row={r} />
                  {r.licenceStatus === "expired" && (
                    <Chip tone="bad">licence expired</Chip>
                  )}
                  {r.licenceStatus === "not_found" && (
                    <Chip tone="neutral">unverified</Chip>
                  )}
                </div>
              </div>

              <div className="text-right shrink-0">
                {q ? (
                  <>
                    <p
                      className={`num text-[length:var(--step-3)] font-bold leading-6 ${
                        best
                          ? "text-[#4ADE80]"
                          : q.stale
                          ? "text-[#6E6C66] line-through"
                          : "text-[#FBFBF7]"
                      }`}
                    >
                      {money(q.comparable)}
                    </p>
                    <p className="text-[10px] text-[#6E6C66] leading-3 mt-0.5">
                      real cost
                    </p>
                  </>
                ) : (
                  <p className="text-[length:var(--step--2)] text-[#55534E] leading-6">
                    {r.status === "declined" ? "not bidding" : "waiting"}
                  </p>
                )}
              </div>
            </div>

            {q && (
              <>
                <div className="mt-3 pt-3 border-t border-[#262624] space-y-1.5">
                  <Row label="They quoted" value={money(q.total)} />
                  {q.hidden > 0 ? (
                    <Row
                      label="Work left out"
                      value={`+ ${money(q.hidden)}`}
                      tone="text-[#FBBF24]"
                    />
                  ) : (
                    <Row label="Work left out" value="nothing" tone="text-[#6E6C66]" />
                  )}
                </div>

                {q.hidden > 0 && (
                  <p className="text-[length:var(--step--2)] text-[#6E6C66] leading-4 mt-2">
                    {q.gaps.map((g) => g.label).join(", ")}
                  </p>
                )}

                {best && (
                  <p className="text-[length:var(--step--2)] text-[#4ADE80] leading-4 mt-2.5">
                    Cheapest once compared fairly
                  </p>
                )}
                {q.stale && (
                  <p className="text-[length:var(--step--2)] text-[#FBBF24] leading-4 mt-2.5">
                    Priced the old job
                  </p>
                )}
                {q.needsReview && !q.stale && !best && (
                  <p className="text-[length:var(--step--2)] text-[#60A5FA] leading-4 mt-2.5">
                    Worth checking by hand
                  </p>
                )}

                <Meta
                  left={
                    q.exclusions.length
                      ? `${q.exclusions.length} not covered`
                      : "covers everything"
                  }
                  right={ago(q.receivedAt)}
                />

                {q.exclusions.length > 0 && (
                  <details className="mt-3 group">
                    <summary className="text-[length:var(--step--2)] text-[#B5B3AA] cursor-pointer list-none flex items-center gap-1.5">
                      <span className="group-open:rotate-90 transition-transform">›</span>
                      What this price does not cover
                    </summary>
                    <ul className="mt-2 space-y-1">
                      {q.exclusions.map((ex) => (
                        <li key={ex} className="text-[length:var(--step--2)] text-[#F87171] leading-4">
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

function Row({ label, value, tone = "text-[#D6D4CC]" }) {
  return (
    <div className="flex items-center justify-between gap-3">
      <span className="text-[length:var(--step--2)] text-[#B5B3AA]">{label}</span>
      <span className={`num text-[length:var(--step--1)] ${tone}`}>{value}</span>
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
