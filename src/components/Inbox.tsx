import { useState } from "react";
import { useAction, useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, Chip, IconBox, Ghost, I } from "./ui";

export default function Inbox({ job, jobId }) {
  const send = useAction(api.agentmail.sendInvitations);
  const reprice = useAction(api.agentmail.requestReprice);
  const ensure = useAction(api.agentmail.ensureInbox);
  const threads = useQuery(api.mail.threadsByJob, { jobId });
  const [busy, setBusy] = useState("");
  const [err, setErr] = useState("");

  const run = async (label, fn) => {
    setBusy(label);
    setErr("");
    try {
      await fn();
    } catch (e) {
      setErr(String(e.message ?? e));
    }
    setBusy("");
  };

  return (
    <Card>
      <div className="flex flex-wrap items-center gap-4 px-5 py-4 border-b border-[#2A2A2A]">
        <IconBox>{I.mail}</IconBox>
        <div className="min-w-0">
          <h2 className="text-[14.5px] font-semibold">This job's inbox</h2>
          <p className="text-[12px] text-[#5A5A5A] mt-0.5 break-all">
            {job.inboxAddress ?? "not created yet"}
          </p>
        </div>
        <div className="ml-auto flex flex-wrap gap-2">
          {!job.inboxAddress && (
            <Ghost disabled={!!busy} onClick={() => run("inbox", () => ensure({ jobId }))}>
              {busy === "inbox" ? "Creating…" : "Create inbox"}
            </Ghost>
          )}
          <Ghost disabled={!!busy} onClick={() => run("invite", () => send({ jobId }))}>
            {busy === "invite" ? "Sending…" : "Ask for prices"}
          </Ghost>
          <Ghost disabled={!!busy} onClick={() => run("chase", () => send({ jobId, chase: true }))}>
            {busy === "chase" ? "Sending…" : "Chase quiet ones"}
          </Ghost>
          <Ghost disabled={!!busy} onClick={() => run("reprice", () => reprice({ jobId }))}>
            {busy === "reprice" ? "Sending…" : "Ask to reprice"}
          </Ghost>
        </div>
      </div>

      {err && (
        <p className="px-5 pt-4 text-[12.5px] text-[#F87171]">{err}</p>
      )}

      <div className="px-5 py-2 divide-y divide-[#242424] max-h-[380px] overflow-y-auto">
        {threads?.length ? (
          threads.map((m) => (
            <div key={m._id} className="py-3.5 flex gap-4">
              <Chip tone={m.direction === "in" ? "good" : "neutral"}>
                {m.direction === "in" ? "in" : "out"}
              </Chip>
              <div className="min-w-0">
                <p className="text-[13px]">
                  {m.direction === "in" ? m.firmName : `To ${m.firmName}`}
                  <span className="text-[#5A5A5A]">
                    {" · "}
                    {m.subject ?? "(no subject)"}
                  </span>
                </p>
                <p className="text-[12.5px] text-[#A1A1A1] mt-1.5 leading-relaxed line-clamp-2 whitespace-pre-line">
                  {m.body.slice(0, 200)}
                </p>
              </div>
            </div>
          ))
        ) : (
          <p className="py-6 text-[12.5px] text-[#5A5A5A]">
            No email yet. Ask the companies for a price to begin.
          </p>
        )}
      </div>
    </Card>
  );
}
