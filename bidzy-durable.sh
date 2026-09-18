#!/bin/bash
# The job outlives the run: durable chases on a schedule, and inbound
# messages that can't be processed twice.
set -e
[ -d convex/quoteEngine ] || { echo "Run from the bidzy project root."; exit 1; }

# ---- schema: index for dedupe ----
python3 - << 'PY'
p = "convex/schema.ts"
s = open(p).read()
if "by_message" not in s:
    s = s.replace(
        '    .index("by_job", ["jobId"])\n    .index("by_thread", ["threadId"]),',
        '    .index("by_job", ["jobId"])\n    .index("by_thread", ["threadId"])\n    .index("by_message", ["messageId"]),'
    )
    open(p, "w").write(s)
    print("messages.by_message added")
else:
    print("index already present")
PY

# ---- dedupe inbound ----
python3 - << 'PY'
p = "convex/mail.ts"
s = open(p).read()
if "already seen" not in s:
    s = s.replace(
        "    const addr = args.fromAddress.toLowerCase().trim();",
        '''    // The same delivery can arrive more than once. Recording the message
    // is what makes the job resumable, so it must happen exactly once.
    if (args.messageId) {
      const seen = await ctx.db
        .query("messages")
        .withIndex("by_message", (q) => q.eq("messageId", args.messageId))
        .first();
      if (seen) return { duplicate: true, already: "seen" };
    }

    const addr = args.fromAddress.toLowerCase().trim();'''
    )
    open(p, "w").write(s)
    print("inbound dedupe in")
else:
    print("dedupe already present")
PY

# ---- the durable chase ----
cat > convex/chase.ts << 'EOF'
import { internalAction, internalMutation, internalQuery } from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";

const DAY = 86400000;
const FIRST_CHASE_AFTER = 3 * DAY;   // silence is normal for a couple of days
const NEXT_CHASE_AFTER = 4 * DAY;    // then a gentler cadence
const MAX_CHASES = 2;                // after that, a human should decide

// Who is genuinely overdue. This is state the app can query, not a
// sentence in a transcript.
export const due = internalQuery({
  args: {},
  handler: async (ctx) => {
    const now = Date.now();
    const out = [];

    const jobs = await ctx.db.query("jobs").collect();
    for (const job of jobs) {
      if (!job.inboxId) continue;

      const invitations = await ctx.db
        .query("invitations")
        .withIndex("by_job", (q) => q.eq("jobId", job._id))
        .collect();

      for (const inv of invitations) {
        if (inv.status === "quoted" || inv.status === "declined") continue;
        if (inv.chaseCount >= MAX_CHASES) continue;

        const since = inv.lastChasedAt ?? inv.sentAt;
        const wait = inv.chaseCount === 0 ? FIRST_CHASE_AFTER : NEXT_CHASE_AFTER;
        if (now - since < wait) continue;

        const firm = await ctx.db.get(inv.firmId);
        if (!firm || !firm.email || firm.email.endsWith("@example.com")) continue;

        out.push({
          invitationId: inv._id,
          jobId: job._id,
          jobName: job.name,
          inboxId: job.inboxId,
          inboxAddress: job.inboxAddress ?? "",
          firmId: firm._id,
          firmName: firm.name,
          email: firm.email,
          chaseCount: inv.chaseCount,
          daysWaiting: Math.floor((now - inv.sentAt) / DAY),
        });
      }
    }
    return out;
  },
});

// Anyone who has run out of chases needs a person, not another email.
export const giveUp = internalMutation({
  args: {},
  handler: async (ctx) => {
    const now = Date.now();
    const invitations = await ctx.db.query("invitations").collect();
    let flagged = 0;

    for (const inv of invitations) {
      if (inv.status === "quoted" || inv.status === "declined") continue;
      if (inv.chaseCount < 2) continue;
      const since = inv.lastChasedAt ?? inv.sentAt;
      if (now - since < 4 * DAY) continue;

      const job = await ctx.db.get(inv.jobId);
      const firm = await ctx.db.get(inv.firmId);
      if (!job || !firm) continue;

      const already = await ctx.db
        .query("events")
        .withIndex("by_job", (q) => q.eq("jobId", inv.jobId))
        .order("desc")
        .take(40);
      if (
        already.some(
          (e) => e.type === "gave_up" && String(e.summary).includes(firm.name)
        )
      )
        continue;

      await ctx.db.insert("events", {
        projectId: job.projectId,
        jobId: inv.jobId,
        type: "gave_up",
        summary: `${firm.name} hasn't answered after ${inv.chaseCount} follow-ups. Worth a phone call or dropping them.`,
        createdAt: now,
      });
      flagged++;
    }
    return { flagged };
  },
});

export const noteChase = internalMutation({
  args: {
    invitationId: v.id("invitations"),
    jobId: v.id("jobs"),
    firmId: v.id("firms"),
    firmName: v.string(),
    subject: v.string(),
    body: v.string(),
    fromAddress: v.string(),
    toAddress: v.string(),
    daysWaiting: v.number(),
    messageId: v.optional(v.string()),
    threadId: v.optional(v.string()),
  },
  handler: async (ctx, a) => {
    const inv = await ctx.db.get(a.invitationId);
    if (!inv) return;
    await ctx.db.patch(a.invitationId, {
      chaseCount: inv.chaseCount + 1,
      lastChasedAt: Date.now(),
      threadId: a.threadId ?? inv.threadId,
    });

    await ctx.db.insert("messages", {
      jobId: a.jobId,
      firmId: a.firmId,
      direction: "out",
      subject: a.subject,
      body: a.body,
      fromAddress: a.fromAddress,
      toAddress: a.toAddress,
      messageId: a.messageId,
      threadId: a.threadId,
      attachments: [],
      kind: "chase",
      createdAt: Date.now(),
    });

    const job = await ctx.db.get(a.jobId);
    if (job) {
      await ctx.db.insert("events", {
        projectId: job.projectId,
        jobId: a.jobId,
        type: "chase_sent",
        summary: `Followed up with ${a.firmName} on its own — ${a.daysWaiting} days without a reply`,
        createdAt: Date.now(),
      });
    }
  },
});

// Runs on a schedule, with nobody watching. The run that asked for the
// price finished days ago; the job did not.
export const run = internalAction({
  args: {},
  handler: async (ctx) => {
    const key = process.env.AGENTMAIL_API_KEY;
    if (!key) return { skipped: "no AGENTMAIL_API_KEY" };

    const pending = await ctx.runQuery(internal.chase.due, {});
    const sent = [];

    for (const p of pending) {
      const subject =
        p.chaseCount === 0
          ? `Following up — pricing for ${p.jobName}`
          : `Still hoping for your price — ${p.jobName}`;

      const body = [
        `Hi ${p.firmName},`,
        ``,
        p.chaseCount === 0
          ? `Just following up on pricing for ${p.jobName} at 42 Marlow Street.`
          : `Checking in once more about ${p.jobName} at 42 Marlow Street.`,
        ``,
        `If you're not bidding this one, a one-line reply is all we need and we'll stop asking.`,
        ``,
        `If you are, please send your price along with anything you're leaving out.`,
        ``,
        `Thanks,`,
        `Bidzy, on behalf of the homeowner`,
      ].join("\n");

      try {
        const res = await fetch(
          `https://api.agentmail.to/v0/inboxes/${p.inboxId}/messages/send`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${key}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              to: p.email,
              subject,
              text: body,
              labels: [`job:${p.jobId}`, "chase", "automatic"],
            }),
          }
        );
        if (!res.ok) continue;
        const json = await res.json();

        await ctx.runMutation(internal.chase.noteChase, {
          invitationId: p.invitationId,
          jobId: p.jobId,
          firmId: p.firmId,
          firmName: p.firmName,
          subject,
          body,
          fromAddress: p.inboxAddress,
          toAddress: p.email,
          daysWaiting: p.daysWaiting,
          messageId: json.message_id ?? json.messageId,
          threadId: json.thread_id ?? json.threadId,
        });
        sent.push(p.firmName);
      } catch {
        // a failed send just means we try again tomorrow
      }
    }

    const { flagged } = await ctx.runMutation(internal.chase.giveUp, {});
    return { chased: sent, flagged };
  },
});
EOF

cat > convex/crons.ts << 'EOF'
import { cronJobs } from "convex/server";
import { internal } from "./_generated/api";

const crons = cronJobs();

// Waiting is only useful if something brings the job back. Nobody has to
// remember to press anything.
crons.daily(
  "chase companies who haven't priced yet",
  { hourUTC: 9, minuteUTC: 0 },
  internal.chase.run
);

export default crons;
EOF

# a button so the cron's behaviour can be shown without waiting a day
cat > convex/chaseNow.ts << 'EOF'
import { action } from "./_generated/server";
import { internal } from "./_generated/api";

// Same code path the daily schedule uses. Here so it can be demonstrated
// without waiting until tomorrow morning.
export const run = action({
  args: {},
  handler: async (ctx) => ctx.runAction(internal.chase.run, {}),
});
EOF

python3 - << 'PY'
p = "src/pages/InboxPage.tsx"
s = open(p).read()
if "chaseNow" not in s:
    s = s.replace(
        "  const ensure = useAction(api.agentmail.ensureInbox);",
        "  const ensure = useAction(api.agentmail.ensureInbox);\n  const autoChase = useAction(api.chaseNow.run);"
    )
    s = s.replace(
        '''              <Ghost disabled={!!busy} onClick={() => run("chase", () => send({ jobId, chase: true }))}>
                {busy === "chase" ? "Sending…" : "Chase quiet ones"}
              </Ghost>''',
        '''              <Ghost disabled={!!busy} onClick={() => run("chase", () => send({ jobId, chase: true }))}>
                {busy === "chase" ? "Sending…" : "Chase quiet ones"}
              </Ghost>
              <Ghost disabled={!!busy} onClick={() => run("auto", () => autoChase({}))}>
                {busy === "auto" ? "Running…" : "Run today's chase"}
              </Ghost>'''
    )
    open(p, "w").write(s)
    print("chase button added")
PY

python3 - << 'PY'
p = "src/components/Feed.tsx"
s = open(p).read()
s = s.replace(
  '  parse_failed: "bg-[#F87171]",',
  '  parse_failed: "bg-[#F87171]",\n  chase_sent: "bg-[#60A5FA]",\n  gave_up: "bg-[#F87171]",'
)
open(p, "w").write(s)
print("feed tones updated")
PY

echo ""
echo "Then: npx convex dev --once"
