#!/bin/bash
# A reply from an address we don't recognise is a real case, not a bug.
set -e
[ -d convex/quoteEngine ] || { echo "Run from the bidzy project root."; exit 1; }

python3 - << 'PY'
p = "convex/mail.ts"
s = open(p).read()

# show the address instead of "Unknown", and say whether we matched it
s = s.replace(
'''    return msgs.map((m) => ({
      ...m,
      firmName: m.firmId ? nameById.get(m.firmId) ?? "Unknown" : "Unknown",
    }));''',
'''    return msgs.map((m) => {
      const known = m.firmId ? nameById.get(m.firmId) : null;
      return {
        ...m,
        firmName: known ?? m.fromAddress,
        unknownSender: !known && m.direction === "in",
      };
    });'''
)

# attach an unrecognised sender to a company, or take them on as a new one
if "attachSender" not in s:
    s += '''

// Someone replied from an address we had not seen: a different mailbox at
// the same company, or a firm we never invited. Either way the price is
// real, so it needs a home rather than being dropped.
export const attachSender = mutation({
  args: {
    messageId: v.id("messages"),
    firmId: v.optional(v.id("firms")),
    newFirmName: v.optional(v.string()),
  },
  handler: async (ctx, { messageId, firmId, newFirmName }) => {
    const message = await ctx.db.get(messageId);
    if (!message) throw new Error("no message");
    const job = await ctx.db.get(message.jobId);
    if (!job) throw new Error("no job");

    let targetId = firmId ?? null;

    if (!targetId) {
      const name = (newFirmName ?? message.fromAddress.split("@")[0]).trim();
      targetId = await ctx.db.insert("firms", {
        name,
        email: message.fromAddress,
        trade: job.trade,
        licenceStatus: "unknown",
      });
      await ctx.db.insert("invitations", {
        jobId: job._id,
        firmId: targetId,
        status: "replied",
        sentAt: message.createdAt,
        chaseCount: 0,
      });
      await ctx.db.insert("events", {
        projectId: job.projectId,
        jobId: job._id,
        type: "reply_received",
        summary: `${name} wrote in without being asked — added to this job`,
        createdAt: Date.now(),
      });
    } else {
      const firm = await ctx.db.get(targetId);
      if (firm) {
        await ctx.db.insert("events", {
          projectId: job.projectId,
          jobId: job._id,
          type: "reply_received",
          summary: `${message.fromAddress} recognised as ${firm.name}`,
          createdAt: Date.now(),
        });
      }
    }

    // every message from that address belongs to them, not just this one
    const all = await ctx.db
      .query("messages")
      .withIndex("by_job", (q) => q.eq("jobId", job._id))
      .collect();
    let linked = 0;
    for (const m of all) {
      if (m.fromAddress === message.fromAddress && !m.firmId) {
        await ctx.db.patch(m._id, { firmId: targetId });
        linked++;
      }
    }

    const firm = await ctx.db.get(targetId);
    if (firm && process.env.GROQ_API_KEY) {
      await ctx.scheduler.runAfter(0, internal.reader.readEmail, {
        jobId: job._id,
        firmId: targetId,
        firmName: firm.name,
        text: message.body,
      });
    }

    return { linked, firmId: targetId };
  },
});
'''
open(p, "w").write(s)
print("attachSender added")
PY

python3 - << 'PY'
p = "src/pages/InboxPage.tsx"
s = open(p).read()

s = s.replace(
  'import { useAction, useQuery } from "convex/react";',
  'import { useAction, useMutation, useQuery } from "convex/react";'
)
s = s.replace(
  "  const autoChase = useAction(api.chaseNow.run);",
  "  const autoChase = useAction(api.chaseNow.run);\n  const attach = useMutation(api.mail.attachSender);\n  const board = useQuery(api.jobs.board, { jobId });"
)

# banner above the message body when we don't know who wrote
s = s.replace(
  '''          {selected ? (
            <pre''',
  '''          {selected?.unknownSender && (
            <UnknownSender
              message={selected}
              rows={board?.rows ?? []}
              onAttach={attach}
            />
          )}
          {selected ? (
            <pre'''
)

s += '''

function UnknownSender({ message, rows, onAttach }) {
  const [busy, setBusy] = useState(false);
  const [choice, setChoice] = useState("");

  return (
    <div className="mx-4 sm:mx-6 mt-5 rounded-xl bg-[#12243D] border border-[#1E3A5F] px-4 py-3.5">
      <p className="text-[12.5px] text-[#60A5FA] leading-5">
        We don't recognise {message.fromAddress}. Their price won't be
        compared until you say who they are.
      </p>
      <div className="flex flex-wrap gap-2 mt-3">
        <select
          value={choice}
          onChange={(e) => setChoice(e.target.value)}
          className="h-9 text-[12.5px] rounded-lg px-3 bg-[#1A1A1A] text-[#EDEDED] border border-[#2E2E2E]"
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
          className="h-9 px-3.5 rounded-lg text-[12.5px] font-medium bg-[#2F7FFF] text-white hover:bg-[#1F6FEF] transition disabled:opacity-40"
        >
          {busy ? "Linking\\u2026" : "Use this price"}
        </button>
      </div>
    </div>
  );
}
'''
open(p, "w").write(s)
print("unknown sender can be claimed")
PY

python3 - << 'PY'
p = "src/pages/InboxPage.tsx"
s = open(p).read()
# the list shows the address, truncated, rather than a bare "Unknown"
s = s.replace(
  '''                      <span className="display text-[12.5px] sm:text-[13px] font-medium truncate">
                        {m.firmName}
                      </span>''',
  '''                      <span
                        className={`display text-[12.5px] sm:text-[13px] font-medium truncate ${
                          m.unknownSender ? "text-[#60A5FA]" : ""
                        }`}
                      >
                        {m.firmName}
                      </span>'''
)
open(p, "w").write(s)
print("list marks unknown senders")
PY

echo ""
echo "Then: npx convex dev --once"
