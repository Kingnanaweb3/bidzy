import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";

const money = (n) =>
  n == null ? "-" : "$" + n.toLocaleString(undefined, { maximumFractionDigits: 0 });

export default function Board({ jobId }) {
  const data = useQuery(api.jobs.board, { jobId });
  if (!data) return <p className="text-sm text-stone-400">Loading board...</p>;

  const {
    job,
    rows,
    allExclusions,
    lowest,
    previousLowest,
    lowestMoved,
    staleCount,
    quotedCount,
    invitedCount,
  } = data;

  return (
    <section>
      <div className="mb-6">
        <h1 className="text-2xl font-semibold tracking-tight">{job.name}</h1>
        <p className="text-sm text-stone-500 mt-1">
          {quotedCount} of {invitedCount} firms have priced this job
        </p>
      </div>

      {lowestMoved && (
        <div className="mb-5 rounded-lg border border-amber-200 bg-amber-50 px-4 py-3">
          <p className="text-sm text-amber-900">
            The design changed and {staleCount} quote
            {staleCount === 1 ? "" : "s"} no longer apply. The best valid price is
            now <strong>{money(lowest)}</strong>, up from {money(previousLowest)}.
          </p>
          <p className="text-xs text-amber-700 mt-1">
            Affected firms have been asked to confirm whether their price still
            holds.
          </p>
        </div>
      )}

      <div className="overflow-x-auto border border-stone-200 rounded-xl bg-white">
        <table className="w-full text-sm border-collapse">
          <thead>
            <tr className="border-b border-stone-200">
              <th className="text-left font-medium text-stone-500 px-5 py-3 w-[180px]">
                Firm
              </th>
              {rows.map((r) => (
                <th
                  key={r.firmId}
                  className="text-left px-5 py-3 min-w-[190px] align-top"
                >
                  <div
                    className={`font-semibold ${
                      r.quote?.stale ? "text-stone-400" : "text-stone-900"
                    }`}
                  >
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
            <tr className="border-b border-stone-100">
              <Label>Quoted price</Label>
              {rows.map((r) => {
                const isLow =
                  r.quote?.total != null &&
                  r.quote.total === lowest &&
                  !r.quote.stale;
                return (
                  <td
                    key={r.firmId}
                    className={`px-5 py-4 transition-opacity duration-500 ${
                      r.quote?.stale ? "opacity-40" : ""
                    }`}
                  >
                    <div
                      className={`text-lg font-semibold tabular-nums ${
                        isLow
                          ? "text-emerald-700"
                          : r.quote?.stale
                          ? "text-stone-400 line-through decoration-stone-300"
                          : "text-stone-900"
                      }`}
                    >
                      {money(r.quote?.total)}
                    </div>
                    {isLow && (
                      <div className="text-[10px] uppercase tracking-wide text-emerald-700 mt-0.5">
                        Best valid price
                      </div>
                    )}
                    {r.quote?.stale && (
                      <div className="text-[10px] text-amber-700 mt-1 leading-tight">
                        Priced against the old design
                      </div>
                    )}
                    {r.quote?.needsReview && !r.quote?.stale && (
                      <div className="text-[10px] text-blue-700 mt-1">
                        Needs review
                      </div>
                    )}
                  </td>
                );
              })}
            </tr>

            <tr className="bg-stone-50">
              <td
                colSpan={rows.length + 1}
                className="px-5 py-2 text-[11px] uppercase tracking-widest text-stone-400"
              >
                What each firm will not do
              </td>
            </tr>

            {allExclusions.map((ex) => (
              <tr key={ex} className="border-b border-stone-100">
                <Label>{ex}</Label>
                {rows.map((r) => {
                  if (!r.quote)
                    return (
                      <td key={r.firmId} className="px-5 py-2.5 text-stone-300">
                        -
                      </td>
                    );
                  const excluded = r.quote.exclusions.includes(ex);
                  return (
                    <td
                      key={r.firmId}
                      className={`px-5 py-2.5 transition-opacity duration-500 ${
                        r.quote.stale ? "opacity-40" : ""
                      }`}
                    >
                      {excluded ? (
                        <span className="text-red-600 font-medium">
                          Not included
                        </span>
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
        A lower price with more exclusions is usually the more expensive bid.
      </p>
    </section>
  );
}

function Label({ children }) {
  return (
    <td className="px-5 py-2.5 text-stone-500 font-medium align-top">
      {children}
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
    quoted: "Quoted",
    sent: "No reply yet",
    opened: "Opened",
    replied: "Replied",
    declined: "Declined",
  };
  return (
    <span
      className={`text-[10px] font-medium border px-1.5 py-0.5 rounded ${
        map[status] ?? map.sent
      }`}
    >
      {text[status] ?? status}
    </span>
  );
}
