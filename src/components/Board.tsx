import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, CardHead, Chip, I, money } from "./ui";
import BoardMobile from "./BoardMobile";

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

  const wide = rows.length > 4;
  const labelW = wide ? 18 : 24;
  const colW = `${Math.floor((100 - labelW) / Math.max(rows.length, 1))}%`;

  return (
    <Card>
      <CardHead
        icon={I.scale}
        title="Price comparison"
        note="Missing work is priced from what the others charged"
      />

      {(lowestMoved || headlineMisleads) && (
        <div className="mx-4 sm:mx-6 mt-5 sm:mt-6 rounded-xl bg-[#2E2410] border border-[#443415] px-4 py-3.5">
          <p className="text-[12.5px] sm:text-[13.5px] text-[#FBBF24] leading-5 sm:leading-6">
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

      <div className="hidden md:block overflow-x-auto p-4 sm:p-6">
        <table className="w-full table-fixed border-collapse min-w-[680px]">
          <colgroup>
            <col style={{ width: `${labelW}%` }} />
            {rows.map((r) => (
              <col key={r.firmId} style={{ width: colW }} />
            ))}
          </colgroup>

          <thead>
            <tr>
              <th className="align-bottom text-left pb-5">
                <div className="h-10" />
                <div className="h-[26px] flex items-end">
                  <span className="text-[12px] font-medium text-[#5A5A5A]">
                    Company
                  </span>
                </div>
              </th>
              {rows.map((r) => (
                <th key={r.firmId} className="align-bottom text-left pb-5 pl-5">
                  <div
                    className={`display h-10 text-[14px] font-semibold leading-5 ${
                      r.quote?.stale ? "text-[#5A5A5A]" : "text-[#EDEDED]"
                    }`}
                  >
                    {r.firmName}
                  </div>
                  <div className="h-[26px] pt-1 flex items-center gap-1.5">
                    <Status row={r} />
                    {r.licenceStatus === "valid" && r.licence?.sourceUrl && (
                      <a
                        href={r.licence.sourceUrl}
                        target="_blank"
                        rel="noreferrer"
                        title={r.licence.evidence ?? "Licence verified"}
                      >
                        <Chip tone="good">licence checked</Chip>
                      </a>
                    )}
                    {r.licenceStatus === "expired" && (
                      <a
                        href={r.licence?.sourceUrl ?? undefined}
                        target="_blank"
                        rel="noreferrer"
                        title={r.licence?.evidence ?? "Licence shows as expired"}
                      >
                        <Chip tone="bad">licence expired</Chip>
                      </a>
                    )}
                    {r.licenceStatus === "not_found" && (
                      <Chip tone="neutral">unverified</Chip>
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
                  {r.quote ? (
                    <span className="num text-[15px] text-[#A1A1A1] leading-6">
                      {money(r.quote.total)}
                    </span>
                  ) : (
                    <Blank row={r} />
                  )}
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
                    <Blank row={r} />
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
                      {r.quote ? (
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
                      )}
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
                      <td key={r.firmId} className="h-11 pl-5 align-middle">
                        <span className="text-[12px] text-[#3A3A3A]">
                          {r.status === "declined" ? "" : "—"}
                        </span>
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

      <div className="md:hidden">
        <BoardMobile d={d} />
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
}
