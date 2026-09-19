import { useState } from "react";
import { useAction, useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, CardHead, Chip, Primary, Empty, Meta, ago, I, money } from "../components/ui";

export default function DocsPage({ jobId }) {
  const d = useQuery(api.jobs.board, { jobId });
  const read = useAction(api.firecrawl.readQuoteDocument);
  const [url, setUrl] = useState("");
  const [firmId, setFirmId] = useState("");
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState("");
  const [err, setErr] = useState("");

  const rows = d?.rows ?? [];
  const active = firmId || rows[0]?.firmId || "";

  const go = async () => {
    if (!url || !active) return;
    setBusy(true);
    setErr("");
    setMsg("");
    const name = rows.find((x) => x.firmId === active)?.firmName ?? "That company";
    try {
      const r = await read({ jobId, firmId: active, url });
      setMsg(
        `${name}: ${r.total != null ? money(r.total) : "no total found"}` +
          (r.exclusions.length ? `, leaving out ${r.exclusions.join(", ")}` : "") +
          (r.needsReview ? ". Worth checking by hand." : "")
      );
      setUrl("");
    } catch (e) {
      setErr(String(e.message ?? e));
    }
    setBusy(false);
  };

  const withDocs = rows.filter((r) => r.quote?.lineItems?.length);

  return (
    <div className="pt-5 sm:pt-6 space-y-5 sm:space-y-6">
      <Card>
        <CardHead
          icon={I.doc}
          title="Read a quote document"
          note="PDFs that arrive by email are read without being asked"
        />
        <div className="p-4 sm:p-6 flex flex-wrap gap-3">
          <select
            value={active}
            onChange={(e) => setFirmId(e.target.value)}
            className="h-10 text-[length:var(--step-0)] rounded-xl px-3.5 bg-[#1C1C1A] text-[#FBFBF7]
              border border-[#262624] hover:border-[#2E2E2B] transition"
          >
            {rows.map((r) => (
              <option key={r.firmId} value={r.firmId}>{r.firmName}</option>
            ))}
          </select>
          <input
            value={url}
            onChange={(e) => setUrl(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && go()}
            placeholder="https://…/quote.pdf"
            className="h-10 flex-1 min-w-[260px] text-[length:var(--step-0)] rounded-xl px-4
              bg-[#1C1C1A] text-[#FBFBF7] border border-[#262624]
              focus:border-[#2F7FFF] outline-none transition"
          />
          <Primary onClick={go} disabled={busy || !url}>
            {busy ? "Reading…" : "Read it"}
          </Primary>
        </div>
        {(msg || err) && (
          <p className={`px-6 pb-6 text-[length:var(--step--1)] leading-5 ${err ? "text-[#F87171]" : "text-[#4ADE80]"}`}>
            {err || msg}
          </p>
        )}
      </Card>

      <Card>
        <CardHead icon={I.scale} title="What we read from each quote" />
        {withDocs.length === 0 ? (
          <Empty>Nothing read yet. Paste a quote PDF above, or let one arrive by email.</Empty>
        ) : (
          <div className="divide-y divide-[#1C1C1A]">
            {withDocs.map((r) => (
              <div key={r.firmId} className="px-4 sm:px-6 py-5">
                <div className="flex flex-wrap items-center gap-3 mb-4">
                  <span className="display text-[length:var(--step-1)] font-semibold">{r.firmName}</span>
                  <span className="num text-[length:var(--step-1)] text-[#B5B3AA]">
                    {money(r.quote.total)}
                  </span>
                  {r.quote.needsReview && <Chip tone="info">worth checking</Chip>}
                  {r.quote.stale && <Chip tone="warn">priced the old job</Chip>}
                </div>
                <div className="grid sm:grid-cols-2 gap-x-8 gap-y-2">
                  {r.quote.lineItems.map((li, i) => (
                    <div key={i} className="flex justify-between gap-4 h-6 items-center">
                      <span className="text-[length:var(--step--2)] sm:text-[length:var(--step--1)] text-[#B5B3AA] truncate">
                        {li.label}
                      </span>
                      <span className="num text-[length:var(--step--2)] sm:text-[length:var(--step--1)] text-[#D6D4CC] shrink-0">
                        {money(li.amount)}
                      </span>
                    </div>
                  ))}
                </div>
                {r.quote.exclusions.length > 0 && (
                  <p className="text-[length:var(--step--1)] text-[#F87171] mt-4 leading-5">
                    Not covered: {r.quote.exclusions.join(", ")}
                  </p>
                )}
                <Meta
                  left={
                    <>
                      {r.quote.lineItems.length} line item
                      {r.quote.lineItems.length === 1 ? "" : "s"} read
                      {r.quote.sourceUrl ? " from a document" : " from an email"}
                    </>
                  }
                  right={ago(r.quote.receivedAt)}
                />
              </div>
            ))}
          </div>
        )}
      </Card>
    </div>
  );
}
