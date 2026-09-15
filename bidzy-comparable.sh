#!/bin/bash
# Surface comparable cost on the board.
set -e
[ -d convex/quoteEngine ] || { echo "Run from the bidzy project root."; exit 1; }

cat > src/components/Board.tsx << 'EOF'
import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";

const money = (n) =>
  n == null ? "-" : "$" + n.toLocaleString(undefined, { maximumFractionDigits: 0 });

export default function Board({ jobId }) {
  const data = useQuery(api.jobs.board, { jobId });
  if (!data) return <p className="text-sm text-stone-400">Loading board...</p>;

  const {
    job, rows, allExclusions, lowest, lowestParty,
    headlineLowest, headlineParty, headlineMisleads,
    previousBest, lowestMoved, staleCount, quotedCount, invitedCount,
  } = data;

  return (
    <section>
      <div className="mb-6">
        <h1 className="text-2xl font-semibold tracking-tight">{job.name}</h1>
        <p className="text-sm text-stone-500 mt-1">
          {quotedCount} of {invitedCount} companies have sent a price
        </p>
      </div>

      {lowestMoved && (
        <div className="mb-4 rounded-lg border border-amber-200 bg-amber-50 px-4 py-3">
          <p className="text-sm text-amber-900">
            You changed the job and {staleCount} price
            {staleCount === 1 ? "" : "s"} no longer apply. The best real cost is
            now <strong>{money(lowest)}</strong> from {lowestParty}, up from{" "}
            {money(previousBest)}.
          </p>
          <p className="text-xs text-amber-700 mt-1">
            We've emailed them to ask whether their price still holds.
          </p>
        </div>
      )}

      {headlineMisleads && !lowestMoved && (
        <div className="mb-4 rounded-lg border border-stone-200 bg-white px-4 py-3">
          <p className="text-sm text-stone-800">
            <strong>{headlineParty}</strong> looks cheapest at{" "}
            {money(headlineLowest)} — but once what they leave out is priced in,{" "}
            <strong>{lowestParty}</strong> is the cheaper job at {money(lowest)}.
          </p>
        </div>
      )}

      <div className="overflow-x-auto border border-stone-200 rounded-xl bg-white">
        <table className="w-full text-sm border-collapse">
          <thead>
            <tr className="border-b border-stone-200">
              <th className="text-left font-medium text-stone-500 px-5 py-3 w-[190px]">
                Company
              </th>
              {rows.map((r) => (
                <th key={r.firmId} className="text-left px-5 py-3 min-w-[190px] align-top">
                  <div className={`font-semibold ${r.quote?.stale ? "text-stone-400" : "text-stone-900"}`}>
                    {r.firmName}
                  </div>
                  <div className="flex items-center gap-1.5 mt-1.5 flex-wrap">
                    <Status status={r.status} stale={r.quote?.stale} />
                    {r.licenceStatus === "expired" && (
                      <span className="text-[10px] font-medium bg-red-50 text-red-700 border border-red-200 px-1.5 py-0.5 rounded">
                        Licence expired
                      </span>
                    )}
                  </div>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {/* headline */}
            <tr className="border-b border-stone-100">
              <Label sub="What they wrote">Quoted price</Label>
              {rows.map((r) => (
                <td key={r.firmId} className={`px-5 py-3 ${r.quote?.stale ? "opacity-40" : ""}`}>
                  <div className={`text-base tabular-nums ${
                    r.quote?.stale ? "text-stone-400 line-through decoration-stone-300" : "text-stone-600"
                  }`}>
                    {money(r.quote?.total)}
                  </div>
                </td>
              ))}
            </tr>

            {/* what they left out, in money */}
            <tr className="border-b border-stone-100">
              <Label sub="Priced from what others charge">Missing work</Label>
              {rows.map((r) => (
                <td key={r.firmId} className={`px-5 py-3 ${r.quote?.stale ? "opacity-40" : ""}`}>
                  {r.quote ? (
                    r.quote.hidden > 0 ? (
                      <div>
                        <div className="text-base tabular-nums text-red-600">
                          + {money(r.quote.hidden)}
                        </div>
                        <div className="text-[10px] text-stone-400 mt-1 leading-tight">
                          {r.quote.gaps.map((g) => g.label).join(", ")}
                        </div>
                      </div>
                    ) : (
                      <span className="text-stone-400 text-xs">Nothing missing</span>
                    )
                  ) : (
                    <span className="text-stone-300">-</span>
                  )}
                </td>
              ))}
            </tr>

            {/* the real number */}
            <tr className="border-b border-stone-200 bg-stone-50/70">
              <Label sub="Like for like">Real cost</Label>
              {rows.map((r) => {
                const isLow =
                  r.quote?.comparable != null &&
                  r.quote.comparable === lowest &&
                  !r.quote.stale;
                return (
                  <td key={r.firmId} className={`px-5 py-4 ${r.quote?.stale ? "opacity-40" : ""}`}>
                    <div className={`text-xl font-semibold tabular-nums ${
                      isLow ? "text-emerald-700"
                        : r.quote?.stale ? "text-stone-400 line-through decoration-stone-300"
                        : "text-stone-900"
                    }`}>
                      {money(r.quote?.comparable)}
                    </div>
                    {isLow && (
                      <div className="text-[10px] uppercase tracking-wide text-emerald-700 mt-0.5">
                        Cheapest job
                      </div>
                    )}
                    {r.quote?.stale && (
                      <div className="text-[10px] text-amber-700 mt-1 leading-tight">
                        Priced the old job
                      </div>
                    )}
                    {r.quote?.needsReview && !r.quote?.stale && (
                      <div className="text-[10px] text-blue-700 mt-1">Needs review</div>
                    )}
                  </td>
                );
              })}
            </tr>

            <tr className="bg-stone-50">
              <td colSpan={rows.length + 1}
                className="px-5 py-2 text-[11px] uppercase tracking-widest text-stone-400">
                What each price does not cover
              </td>
            </tr>

            {allExclusions.map((ex) => (
              <tr key={ex} className="border-b border-stone-100">
                <Label>{ex}</Label>
                {rows.map((r) => {
                  if (!r.quote)
                    return <td key={r.firmId} className="px-5 py-2.5 text-stone-300">-</td>;
                  const excluded = r.quote.exclusions.includes(ex);
                  return (
                    <td key={r.firmId} className={`px-5 py-2.5 ${r.quote.stale ? "opacity-40" : ""}`}>
                      {excluded ? (
                        <span className="text-red-600 font-medium">Not included</span>
                      ) : (
                        <span className="text-emerald-700">Included</span>
                      )}
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <p className="text-xs text-stone-400 mt-3">
        Missing work is priced using what the other companies charged for the same
        item, so every quote can be compared like for like.
      </p>
    </section>
  );
}

function Label({ children, sub }) {
  return (
    <td className="px-5 py-2.5 align-top">
      <div className="text-stone-600 font-medium">{children}</div>
      {sub && <div className="text-[10px] text-stone-400 mt-0.5">{sub}</div>}
    </td>
  );
}

function Status({ status, stale }) {
  if (stale)
    return (
      <span className="text-[10px] font-medium border px-1.5 py-0.5 rounded bg-amber-50 text-amber-700 border-amber-200">
        Needs repricing
      </span>
    );
  const map = {
    quoted: "bg-emerald-50 text-emerald-700 border-emerald-200",
    sent: "bg-stone-50 text-stone-500 border-stone-200",
    opened: "bg-blue-50 text-blue-700 border-blue-200",
    replied: "bg-blue-50 text-blue-700 border-blue-200",
    declined: "bg-stone-50 text-stone-400 border-stone-200",
  };
  const text = {
    quoted: "Quoted", sent: "No reply yet", opened: "Opened",
    replied: "Replied", declined: "Declined",
  };
  return (
    <span className={`text-[10px] font-medium border px-1.5 py-0.5 rounded ${map[status] ?? map.sent}`}>
      {text[status] ?? status}
    </span>
  );
}
EOF

echo "board updated"
