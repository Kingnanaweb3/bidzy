import { useState } from "react";
import { useAction, useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";

export default function ReadDoc({ jobId, rows }) {
  const read = useAction(api.firecrawl.readQuoteDocument);
  const [url, setUrl] = useState("");
  const [firmId, setFirmId] = useState(rows?.[0]?.firmId ?? "");
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState("");
  const [err, setErr] = useState("");

  const go = async () => {
    if (!url || !firmId) return;
    setBusy(true);
    setErr("");
    setMsg("");
    try {
      const r = await read({ jobId, firmId, url });
      setMsg(
        `Read ${r.total != null ? "$" + r.total.toLocaleString() : "no total"}` +
          (r.exclusions.length
            ? ` - not covered: ${r.exclusions.join(", ")}`
            : "") +
          (r.needsReview ? " (flagged for review)" : "")
      );
      setUrl("");
    } catch (e) {
      setErr(String(e.message ?? e));
    }
    setBusy(false);
  };

  return (
    <section className="mt-10">
      <h2 className="text-[11px] uppercase tracking-widest text-stone-400 mb-1">
        Read a quote document
      </h2>
      <p className="text-xs text-stone-500 mb-4">
        Paste the link to a PDF quote. Emailed PDFs are read automatically.
      </p>

      <div className="flex gap-2 flex-wrap">
        <select
          value={firmId}
          onChange={(e) => setFirmId(e.target.value)}
          className="text-sm border border-stone-300 rounded-md px-3 py-2 bg-white"
        >
          {rows?.map((r) => (
            <option key={r.firmId} value={r.firmId}>
              {r.firmName}
            </option>
          ))}
        </select>
        <input
          value={url}
          onChange={(e) => setUrl(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && go()}
          placeholder="https://.../quote.pdf"
          className="flex-1 min-w-[280px] text-sm border border-stone-300 rounded-md px-3 py-2"
        />
        <button
          onClick={go}
          disabled={busy || !url}
          className="text-xs font-medium bg-stone-900 text-white px-4 py-2 rounded-md hover:bg-stone-700 disabled:bg-stone-200 disabled:text-stone-400"
        >
          {busy ? "Reading..." : "Read it"}
        </button>
      </div>

      {msg && (
        <p className="mt-3 text-sm text-emerald-800 bg-emerald-50 border border-emerald-200 rounded-md px-3 py-2">
          {msg}
        </p>
      )}
      {err && (
        <p className="mt-3 text-xs text-red-700 bg-red-50 border border-red-200 rounded-md px-3 py-2">
          {err}
        </p>
      )}
    </section>
  );
}
