import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, CardHead, Chip, I, money } from "./ui";

export default function Board({ jobId }) {
  const d = useQuery(api.jobs.board, { jobId });
  if (!d)
    return (
      <Card>
        <CardHead icon={I.scale} title="Price comparison" note="loading" />
      </Card>
    );

  const {
    rows, allExclusions, lowest, lowestParty,
    headlineLowest, headlineParty, headlineMisleads,
    previousBest, lowestMoved, staleCount,
  } = d;

  const colW = `${Math.floor(76 / Math.max(rows.length, 1))}%`;

  return (
    <Card>
      <CardHead
        icon={I.scale}
        title="Price comparison"
        note="Missing work is priced from what the others charged"
      />

      {(lowestMoved || headlineMisleads) && (
        <div className="mx-6 mt-6 rounded-xl bg-[#2E2410] border border-[#443415] px-4 py-3.5">
          <p className="text-[13.5px] text-[#FBBF24] leading-6">
            {lowestMoved ? (
              <>
                You changed the job, so {staleCount} price
                {staleCount === 1 ? "" : "s"} no longer{" "}
                {staleCount === 1 ? "applies" : "apply"}. {lowestParty} already
                priced this and still stands at {money(lowest)}, up from{" "}
                {money(previousBest)}.
              </>
            ) : (
              <>
                {headlineParty} looks cheapest at {money(headlineLowest)} — but
                once the work they leave out is priced in, {lowestParty} is the
                cheaper job at {money(lowest)}.
              </>
            )}
          </p>
        </div>
      )}

      <div className="overflow-x-auto p-6">
        <table className="w-full table-fixed border-collapse min-w-[760px]">
          <colgroup>
            <col style={{ width: "24%" }} />
            {rows.map((r) => (
              <col key={r.firmId} style={{ width: colW }} />
            ))}
          </colgroup>

          <thead>
            <tr>
              <th className="align-bottom text-left pb-5">
                <div className="h-5" />
                <div className="h-[26px] flex items-end">
                  <span className="text-[12px] font-medium text-[#5A5A5A]">
                    Company
                  </span>
                </div>
              </th>
              {rows.map((r) => (
                <th key={r.firmId} className="align-bottom text-left pb-5 pl-5">
                  <div
                    className={`h-5 text-[14px] font-semibold leading-5 truncate ${
                      r.quote?.stale ? "text-[#5A5A5A]" : "text-[#EDEDED]"
                    }`}
                  >
                    {r.firmName}
                  </div>
                  <div className="h-[26px] pt-1 flex items-center gap-1.5 overflow-hidden">
                    <Status row={r} />
                    {r.licenceStatus === "expired" && (
                      <Chip tone="bad">licence expired</Chip>
                    )}
                  </div>
                </th>
              ))}
            </tr>
          </thead>

          <tbody>
            <Line label="Quoted" note="what they wrote">
              {rows.map((r) => (
                <td
                  key={r.firmId}
                  className={`py-4 pl-5 align-top ${r.quote?.stale ? "opacity-40" : ""}`}
                >
                  <span className="num text-[15px] text-[#A1A1A1] leading-6">
                    {money(r.quote?.total)}
                  </span>
                </td>
              ))}
            </Line>

            <Line label="Missing work" note="priced from the others">
              {rows.map((r) => (
                <td
                  key={r.firmId}
                  className={`py-4 pl-5 align-top ${r.quote?.stale ? "opacity-40" : ""}`}
                >
                  {r.quote ? (
                    r.quote.hidden > 0 ? (
                      <>
                        <span className="num text-[15px] text-[#FBBF24] leading-6">
                          + {money(r.quote.hidden)}
                        </span>
                        <span className="block text-[11.5px] text-[#5A5A5A] mt-1.5 leading-5">
                          {r.quote.gaps.map((g) => g.label).join(", ")}
                        </span>
                      </>
                    ) : (
                      <span className="text-[12.5px] text-[#5A5A5A] leading-6">
                        nothing left out
                      </span>
                    )
                  ) : (
                    <span className="text-[#3A3A3A] leading-6">—</span>
                  )}
                </td>
              ))}
            </Line>

            <tr className="border-t border-[#242424]">
              <td className="py-5 pr-5 align-top">
                <div className="text-[13.5px] font-semibold leading-5">Real cost</div>
                <div className="text-[11.5px] text-[#5A5A5A] leading-4 mt-0.5">
                  like for like
                </div>
              </td>
              {rows.map((r) => {
                const best =
                  r.quote?.comparable != null &&
                  r.quote.comparable === lowest &&
                  !r.quote.stale;
                return (
                  <td
                    key={r.firmId}
                    className={`py-5 pl-5 align-top ${r.quote?.stale ? "opacity-40" : ""}`}
                  >
                    <div
                      className={`rounded-xl px-4 py-3.5 border min-h-[84px] ${
                        best
                          ? "bg-[#0F2C1F] border-[#1B4A33]"
                          : "bg-[#242424] border-[#2E2E2E]"
                      }`}
                    >
                      <span
                        className={`num block text-[22px] font-bold tracking-tight leading-7 ${
                          best
                            ? "text-[#4ADE80]"
                            : r.quote?.stale
                            ? "text-[#5A5A5A] line-through"
                            : "text-[#EDEDED]"
                        }`}
                      >
                        {money(r.quote?.comparable)}
                      </span>
                      <span className="block text-[11px] mt-1.5 leading-4 min-h-[16px]">
                        {best && (
                          <span className="text-[#4ADE80]">
                            cheapest once compared fairly
                          </span>
                        )}
                        {r.quote?.stale && (
                          <span className="text-[#FBBF24]">priced the old job</span>
                        )}
                        {r.quote?.needsReview && !r.quote?.stale && !best && (
                          <span className="text-[#60A5FA]">worth checking</span>
                        )}
                      </span>
                    </div>
                  </td>
                );
              })}
            </tr>

            {allExclusions.length > 0 && (
              <tr>
                <td
                  colSpan={rows.length + 1}
                  className="pt-8 pb-3 text-[12px] font-medium text-[#5A5A5A]"
                >
                  What each price does not cover
                </td>
              </tr>
            )}

            {allExclusions.map((ex) => (
              <tr key={ex} className="border-t border-[#242424]">
                <td className="h-11 pr-5 text-[12.5px] text-[#A1A1A1] align-middle">
                  {ex}
                </td>
                {rows.map((r) => {
                  if (!r.quote)
                    return (
                      <td key={r.firmId} className="h-11 pl-5 text-[#3A3A3A] align-middle">
                        —
                      </td>
                    );
                  const out = r.quote.exclusions.includes(ex);
                  return (
                    <td
                      key={r.firmId}
                      className={`h-11 pl-5 align-middle ${r.quote.stale ? "opacity-40" : ""}`}
                    >
                      <span className={`text-[12px] ${out ? "text-[#F87171]" : "text-[#4ADE80]"}`}>
                        {out ? "not covered" : "covered"}
                      </span>
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Card>
  );
}

function Line({ label, note, children }) {
  return (
    <tr className="border-t border-[#242424]">
      <td className="py-4 pr-5 align-top">
        <div className="text-[13px] text-[#EDEDED] leading-6">{label}</div>
        <div className="text-[11.5px] text-[#5A5A5A] leading-4 mt-0.5">{note}</div>
      </td>
      {children}
    </tr>
  );
}

function Status({ row }) {
  if (row.quote?.stale) return <Chip tone="warn">needs repricing</Chip>;
  if (row.quote) return <Chip tone="good">replied</Chip>;
  if (row.chaseCount > 0) return <Chip tone="neutral">chased {row.chaseCount}×</Chip>;
  return <Chip tone="neutral">no reply yet</Chip>;
}
