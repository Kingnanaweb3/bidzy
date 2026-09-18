import { useState } from "react";
import { useAction } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, IconBox, Primary, I } from "./ui";

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
    const name = rows.find((x) => x.firmId === firmId)?.firmName ?? "That company";
    try {
      const r = await read({ jobId, firmId, url });
      setMsg(
        `${name}: ${r.total != null ? "$" + r.total.toLocaleString() : "no total found"}` +
          (r.exclusions.length ? `, leaving out ${r.exclusions.join(", ")}` : "") +
          (r.needsReview ? ". Worth checking by hand." : "")
      );
      setUrl("");
    } catch (e) {
      setErr(String(e.message ?? e));
    }
    setBusy(false);
  };

  return (
    <Card>
      <div className="flex items-center gap-3 px-5 py-4 border-b border-[#2A2A2A]">
        <IconBox>{I.doc}</IconBox>
        <div>
          <h2 className="text-[14.5px] font-semibold">Read a quote document</h2>
          <p className="text-[12px] text-[#5A5A5A] mt-0.5">
            PDFs that arrive by email are read without being asked
          </p>
        </div>
      </div>

      <div className="p-5 flex flex-wrap gap-3">
        <select
          value={firmId}
          onChange={(e) => setFirmId(e.target.value)}
          className="text-[13.5px] rounded-xl px-3.5 py-2.5 bg-[#242424] text-[#EDEDED]
            border border-[#2E2E2E] hover:border-[#3A3A3A] transition"
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
          placeholder="https://…/quote.pdf"
          className="flex-1 min-w-[260px] text-[13.5px] rounded-xl px-4 py-2.5
            bg-[#242424] text-[#EDEDED] border border-[#2E2E2E]
            focus:border-[#2F7FFF] outline-none transition"
        />
        <Primary onClick={go} disabled={busy || !url}>
          {busy ? "Reading…" : "Read it"}
        </Primary>
      </div>

      {(msg || err) && (
        <p
          className={`px-5 pb-5 text-[12.5px] ${
            err ? "text-[#F87171]" : "text-[#4ADE80]"
          }`}
        >
          {err || msg}
        </p>
      )}
    </Card>
  );
}
