import { useState } from "react";
import { useAction, useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, CardHead, Chip, Ghost, Empty, I, when } from "../components/ui";

export default function InboxPage({ job, jobId }) {
  const send = useAction(api.agentmail.sendInvitations);
  const reprice = useAction(api.agentmail.requestReprice);
  const ensure = useAction(api.agentmail.ensureInbox);
  const threads = useQuery(api.mail.threadsByJob, { jobId });
  const [busy, setBusy] = useState("");
  const [err, setErr] = useState("");
  const [open, setOpen] = useState(null);

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

  const selected = threads?.find((m) => m._id === open) ?? threads?.[0];

  return (
    <div className="pt-6 space-y-6">
      <Card>
        <CardHead
          icon={I.mail}
          title={job.inboxAddress ?? "No inbox yet"}
          note="Companies reply to this address like any other email"
          right={
            <div className="flex flex-wrap gap-2">
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
          }
        />
        {err && <p className="px-6 py-4 text-[12.5px] text-[#F87171]">{err}</p>}
      </Card>

      <div className="grid grid-cols-1 xl:grid-cols-[380px_minmax(0,1fr)] gap-6">
        <Card className="h-fit">
          <CardHead icon={I.mail} title="Messages" note={`${threads?.length ?? 0} in this thread`} />
          {threads && threads.length === 0 ? (
            <Empty>No email yet. Use “Ask for prices” above and the replies land here.</Empty>
          ) : (
            <ul className="divide-y divide-[#242424] max-h-[560px] overflow-y-auto">
              {threads?.map((m) => (
                <li key={m._id}>
                  <button
                    onClick={() => setOpen(m._id)}
                    className={`w-full text-left px-6 py-4 transition ${
                      selected?._id === m._id ? "bg-[#242424]" : "hover:bg-[#1C1C1C]"
                    }`}
                  >
                    <div className="flex items-center gap-2.5 mb-1.5">
                      <Chip tone={m.direction === "in" ? "good" : "neutral"}>
                        {m.direction === "in" ? "in" : "out"}
                      </Chip>
                      <span className="text-[13px] font-medium truncate">
                        {m.firmName}
                      </span>
                      <span className="ml-auto text-[11px] text-[#5A5A5A] shrink-0">
                        {when(m.createdAt)}
                      </span>
                    </div>
                    <p className="text-[12.5px] text-[#A1A1A1] truncate leading-5">
                      {m.subject ?? "(no subject)"}
                    </p>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </Card>

        <Card className="h-fit">
          <CardHead
            icon={I.doc}
            title={selected?.subject ?? "Nothing selected"}
            note={
              selected
                ? `${selected.direction === "in" ? "From" : "To"} ${selected.firmName} · ${when(selected.createdAt)}`
                : undefined
            }
          />
          {selected ? (
            <pre className="px-6 py-6 text-[13px] text-[#C9C9C9] leading-6 whitespace-pre-wrap font-sans">
              {selected.body}
            </pre>
          ) : (
            <Empty>Pick a message to read it.</Empty>
          )}
        </Card>
      </div>
    </div>
  );
}
