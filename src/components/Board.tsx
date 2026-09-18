import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, Chip, IconBox, I } from "./ui";

const money = (n) =>
  n == null ? "—" : "$" + n.toLocaleString(undefined, { maximumFractionDigits: 0 });

export default function Board({ jobId }) {
  const d = useQuery(api.jobs.board, { jobId });
  if (!d) return <Card className="p-5 text-[13px] text-[#5A5A5A]">Loading…</Card>;

  const {
    rows, allExclusions, lowest, lowestParty,
    headlineLowest, headlineParty, headlineMisleads,
    previousBest, lowestMoved, staleCount,
  } = d;

  return (
    <Card>
      <div className="flex items-center gap-3 px-5 py-4 border-b border-[#2A2A2A]">
        <IconBox>{I.scale}</IconBox>
        <div>
          <h2 className="text-[14.5px] font-semibold">Price comparison</h2>
          <p className="text-[12px] text-[#5A5A5A] mt-0.5">
            Missing work is priced from what the others charged
          </p>
        </div>
      </div>

      {(lowestMoved || headlineMisleads) && (
        <div className="mx-5 mt-5 rounded-xl bg-[#2E2410] border border-[#443415] px-4 py-3.5">
          <p className="text-[13.5px] text-[#FBBF24] leading-relaxed">
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

      <div className="overflow-x-auto p-5">
        <table className="w-full border-collapse text-[13.5px] min-w-[700px]">
          <thead>
            <tr className="text-left">
              <th className="w-[140px] pb-3 text-[12px] font-medium text-[#5A5A5A]">
                Company
              </th>
              {rows.map((r) => (
                <th key={r.firmId} className="pb-3 px-4 min-w-[168px]">
                  <div
                    className={`font-semibold ${
                      r.quote?.stale ? "text-[#5A5A5A]" : "text-[#EDEDED]"
                    }`}
                  >
                    {r.firmName}
                  </div>
                  <div className="flex flex-wrap gap-1.5 mt-2">
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
                  className={`px-4 py-3 ${r.quote?.stale ? "opacity-40" : ""}`}
                >
                  <span className="num text-[15px] text-[#A1A1A1]">
                    {money(r.quote?.total)}
                  </span>
                </td>
              ))}
            </Line>

            <Line label="Missing work" note="priced from the others">
              {rows.map((r) => (
                <td
                  key={r.firmId}
                  className={`px-4 py-3 align-top ${
                    r.quote?.stale ? "opacity-40" : ""
                  }`}
                >
                  {r.quote ? (
                    r.quote.hidden > 0 ? (
                      <>
                        <span className="num text-[15px] text-[#FBBF24]">
                          + {money(r.quote.hidden)}
                        </span>
                        <span className="block text-[11.5px] text-[#5A5A5A] mt-1.5 leading-snug">
                          {r.quote.gaps.map((g) => g.label).join(", ")}
                        </span>
                      </>
                    ) : (
                      <span className="text-[12.5px] text-[#5A5A5A]">
                        nothing left out
                      </span>
                    )
                  ) : (
                    <span className="text-[#3A3A3A]">—</span>
                  )}
                </td>
              ))}
            </Line>

            <tr>
              <td className="pt-4 pr-4 align-top">
                <div className="text-[13.5px] font-semibold">Real cost</div>
                <div className="text-[11.5px] text-[#5A5A5A] mt-0.5">
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
                    className={`px-4 pt-4 pb-1 align-top ${
                      r.quote?.stale ? "opacity-40" : ""
                    }`}
                  >
                    <div
                      className={`rounded-xl px-3.5 py-3 border ${
                        best
                          ? "bg-[#0F2C1F] border-[#1B4A33]"
                          : "bg-[#242424] border-[#2E2E2E]"
                      }`}
                    >
                      <span
                        className={`num text-[22px] font-bold tracking-tight ${
                          best
                            ? "text-[#4ADE80]"
                            : r.quote?.stale
                            ? "text-[#5A5A5A] line-through"
                            : "text-[#EDEDED]"
                        }`}
                      >
                        {money(r.quote?.comparable)}
                      </span>
                      {best && (
                        <span className="block text-[11px] text-[#4ADE80] mt-1">
                          cheapest once compared fairly
                        </span>
                      )}
                      {r.quote?.stale && (
                        <span className="block text-[11px] text-[#FBBF24] mt-1">
                          priced the old job
                        </span>
                      )}
                      {r.quote?.needsReview && !r.quote?.stale && (
                        <span className="block text-[11px] text-[#60A5FA] mt-1">
                          worth checking
                        </span>
                      )}
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
                <td className="py-2.5 pr-4 text-[12.5px] text-[#A1A1A1] align-top">
                  {ex}
                </td>
                {rows.map((r) => {
                  if (!r.quote)
                    return (
                      <td key={r.firmId} className="px-4 py-2.5 text-[#3A3A3A]">
                        —
                      </td>
                    );
                  const out = r.quote.exclusions.includes(ex);
                  return (
                    <td
                      key={r.firmId}
                      className={`px-4 py-2.5 ${r.quote.stale ? "opacity-40" : ""}`}
                    >
                      <span
                        className={`text-[12px] ${
                          out ? "text-[#F87171]" : "text-[#4ADE80]"
                        }`}
                      >
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
      <td className="py-3 pr-4 align-top">
        <div className="text-[13px] text-[#EDEDED]">{label}</div>
        <div className="text-[11.5px] text-[#5A5A5A] mt-0.5">{note}</div>
      </td>
      {children}
    </tr>
  );
}

function Status({ row }) {
  if (row.quote?.stale) return <Chip tone="warn">needs repricing</Chip>;
  if (row.quote) return <Chip tone="good">replied</Chip>;
  if (row.chaseCount > 0)
    return <Chip tone="neutral">chased {row.chaseCount}×</Chip>;
  return <Chip tone="neutral">no reply yet</Chip>;
}
