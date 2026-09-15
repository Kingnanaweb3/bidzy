import { useState } from "react";
import { useAction, useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";

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
    <section className="mt-10">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h2 className="text-[11px] uppercase tracking-widest text-stone-400">
            This project's inbox
          </h2>
          <p className="text-sm text-stone-600 mt-1 font-mono">
            {job.inboxAddress ?? "not created yet"}
          </p>
        </div>
        <div className="flex gap-2">
          {!job.inboxAddress && (
            <button
              onClick={() => run("inbox", () => ensure({ jobId }))}
              disabled={!!busy}
              className="text-xs font-medium border border-stone-300 px-3 py-2 rounded-md hover:bg-stone-50 disabled:opacity-40"
            >
              {busy === "inbox" ? "Creating..." : "Create inbox"}
            </button>
          )}
          <button
            onClick={() => run("invite", () => send({ jobId }))}
            disabled={!!busy}
            className="text-xs font-medium border border-stone-300 px-3 py-2 rounded-md hover:bg-stone-50 disabled:opacity-40"
          >
            {busy === "invite" ? "Sending..." : "Ask for prices"}
          </button>
          <button
            onClick={() => run("chase", () => send({ jobId, chase: true }))}
            disabled={!!busy}
            className="text-xs font-medium border border-stone-300 px-3 py-2 rounded-md hover:bg-stone-50 disabled:opacity-40"
          >
            {busy === "chase" ? "Sending..." : "Chase who hasn't replied"}
          </button>
          <button
            onClick={() => run("reprice", () => reprice({ jobId }))}
            disabled={!!busy}
            className="text-xs font-medium border border-stone-300 px-3 py-2 rounded-md hover:bg-stone-50 disabled:opacity-40"
          >
            {busy === "reprice" ? "Sending..." : "Ask affected companies to reprice"}
          </button>
        </div>
      </div>

      {err && (
        <div className="mb-4 text-xs text-red-700 bg-red-50 border border-red-200 rounded-md px-3 py-2">
          {err}
        </div>
      )}

      <div className="border border-stone-200 rounded-xl bg-white divide-y divide-stone-100">
        {threads?.length ? (
          threads.map((m) => (
            <div key={m._id} className="px-5 py-3 flex gap-4">
              <span
                className={`mt-1 text-[10px] font-medium px-1.5 py-0.5 rounded h-fit shrink-0 ${
                  m.direction === "in"
                    ? "bg-blue-50 text-blue-700 border border-blue-200"
                    : "bg-stone-50 text-stone-500 border border-stone-200"
                }`}
              >
                {m.direction === "in" ? "IN" : "OUT"}
              </span>
              <div className="min-w-0">
                <p className="text-sm font-medium text-stone-900">
                  {m.direction === "in" ? m.firmName : `To ${m.firmName}`}
                  <span className="font-normal text-stone-400">
                    {" "}
                    - {m.subject ?? "(no subject)"}
                  </span>
                </p>
                <p className="text-xs text-stone-500 mt-1 line-clamp-2 whitespace-pre-line">
                  {m.body.slice(0, 220)}
                </p>
                <p className="text-[11px] text-stone-400 mt-1">
                  {new Date(m.createdAt).toLocaleString(undefined, {
                    month: "short",
                    day: "numeric",
                    hour: "numeric",
                    minute: "2-digit",
                  })}
                </p>
              </div>
            </div>
          ))
        ) : (
          <p className="px-5 py-6 text-sm text-stone-400">
            No email yet. Create the inbox, then ask the companies for a price.
          </p>
        )}
      </div>
    </section>
  );
}
