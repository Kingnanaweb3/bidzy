import { useState } from "react";
import { useAction, useMutation, useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, CardHead, Chip, Ghost, Empty, Meta, I, when, ago } from "../components/ui";

export default function InboxPage({ job, jobId }) {
  const send = useAction(api.agentmail.sendInvitations);
  const reprice = useAction(api.agentmail.requestReprice);
  const ensure = useAction(api.agentmail.ensureInbox);
  const autoChase = useAction(api.chaseNow.run);
  const attach = useMutation(api.mail.attachSender);
  const verifyAll = useAction(api.verify.checkAll);
  const board = useQuery(api.jobs.board, { jobId });
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
    <div className="pt-5 sm:pt-6 space-y-5 sm:space-y-6">
      <Card>
        <CardHead
          icon={I.mail}
          title={<span className="mono">{job.inboxAddress ?? "No inbox yet"}</span>}
          note="Companies reply to this address like any other email"
          right={
            <div className="flex flex-wrap gap-2 w-full sm:w-auto">
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
              <Ghost disabled={!!busy} onClick={() => run("auto", () => autoChase({}))}>
                {busy === "auto" ? "Running…" : "Run today's chase"}
              </Ghost>
              <Ghost disabled={!!busy} onClick={() => run("reprice", () => reprice({ jobId }))}>
                {busy === "reprice" ? "Sending…" : "Ask to reprice"}
              </Ghost>
              <Ghost disabled={!!busy} onClick={() => run("verify", () => verifyAll({ jobId }))}>
                {busy === "verify" ? "Checking…" : "Check licences"}
              </Ghost>
            </div>
          }
        />
        {err && <p className="px-6 py-4 text-[length:var(--step--1)] text-[#F87171]">{err}</p>}
      </Card>

      <div className="grid grid-cols-1 xl:grid-cols-[360px_minmax(0,1fr)] gap-5 sm:gap-6">
        <Card className="h-fit">
          <CardHead icon={I.mail} title="Messages" note={`${threads?.length ?? 0} in this thread`} />
          {threads && threads.length === 0 ? (
            <Empty>No email yet. Use “Ask for prices” above and the replies land here.</Empty>
          ) : (
            <ul className="divide-y divide-[#1C1C1A] max-h-[560px] overflow-y-auto">
              {threads?.map((m) => (
                <li key={m._id}>
                  <button
                    onClick={() => setOpen(m._id)}
                    className={`w-full text-left px-6 py-4 transition ${
                      selected?._id === m._id ? "bg-[#1C1C1A]" : "hover:bg-[#1C1C1C]"
                    }`}
                  >
                    <div className="flex items-center gap-2.5 mb-1.5">
                      <Chip tone={m.direction === "in" ? "good" : "neutral"}>
                        {m.direction === "in" ? "in" : "out"}
                      </Chip>
                      <span
                        className={`display text-[length:var(--step--1)] sm:text-[length:var(--step-0)] font-medium truncate ${
                          m.unknownSender ? "text-[#60A5FA]" : ""
                        }`}
                      >
                        {m.firmName}
                      </span>
                      <span className="ml-auto text-[length:var(--step--2)] text-[#6E6C66] shrink-0">
                        {when(m.createdAt)}
                      </span>
                    </div>
                    <p className="text-[length:var(--step--1)] text-[#B5B3AA] truncate leading-5">
                      {m.subject ?? "(no subject)"}
                    </p>
                    <p className="mono text-[length:var(--step--2)] text-[#6E6C66] truncate mt-1">
                      {m.direction === "in" ? m.fromAddress : m.toAddress}
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
          {selected?.unknownSender && (
            <UnknownSender
              message={selected}
              rows={board?.rows ?? []}
              onAttach={attach}
            />
          )}
          {selected ? (
            <pre className="px-4 sm:px-6 py-5 sm:py-6 text-[length:var(--step-0)] text-[#D6D4CC] leading-6 whitespace-pre-wrap font-sans">
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


function UnknownSender({ message, rows, onAttach }) {
  const [busy, setBusy] = useState(false);
  const [choice, setChoice] = useState("");

  return (
    <div className="mx-4 sm:mx-6 mt-5 rounded-xl bg-[#12243D] border border-[#1E3A5F] px-4 py-3.5">
      <p className="text-[length:var(--step--1)] text-[#60A5FA] leading-5">
        We don't recognise <span className="mono">{message.fromAddress}</span>. Their price won't be
        compared until you say who they are.
      </p>
      <div className="flex flex-wrap gap-2 mt-3">
        <select
          value={choice}
          onChange={(e) => setChoice(e.target.value)}
          className="h-9 text-[length:var(--step--1)] rounded-lg px-3 bg-[#121212] text-[#FBFBF7] border border-[#262624]"
        >
          <option value="">Add as a new company</option>
          {rows.map((r) => (
            <option key={r.firmId} value={r.firmId}>
              This is {r.firmName}
            </option>
          ))}
        </select>
        <button
          disabled={busy}
          onClick={async () => {
            setBusy(true);
            await onAttach({
              messageId: message._id,
              firmId: choice || undefined,
            });
            setBusy(false);
          }}
          className="h-9 px-3.5 rounded-lg text-[length:var(--step--1)] font-medium bg-[#2F7FFF] text-white hover:bg-[#1F6FEF] transition disabled:opacity-40"
        >
          {busy ? "Linking\u2026" : "Use this price"}
        </button>
      </div>
    </div>
  );
}
