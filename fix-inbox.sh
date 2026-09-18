#!/bin/bash
set -e

cat > convex/demo.ts << 'EOF'
import { mutation } from "./_generated/server";
import { components } from "./_generated/api";

// Puts the project back to "we've asked, nobody has replied yet" so the
// email loop can be shown from the beginning. Keeps the inbox.
export const awaitingReplies = mutation({
  args: {},
  handler: async (ctx) => {
    const jobs = await ctx.db.query("jobs").collect();
    for (const job of jobs) {
      await ctx.runMutation(components.quoteEngine.quotes.clearJob, {
        jobKey: String(job._id),
      });
    }
    const invs = await ctx.db.query("invitations").collect();
    for (const i of invs) {
      await ctx.db.patch(i._id, { status: "sent", chaseCount: 0 });
    }
    const msgs = await ctx.db.query("messages").collect();
    for (const m of msgs) await ctx.db.delete(m._id);
    return { reset: invs.length };
  },
});
EOF

python3 - << 'PY'
p = "convex/agentmail.ts"
s = open(p).read()

old = s[s.index("export const ensureInbox = action({"):s.index("// Register the Convex HTTP endpoint")]
new = '''export const ensureInbox = action({
  args: { jobId: v.id("jobs"), username: v.optional(v.string()) },
  handler: async (ctx, { jobId, username }) => {
    const job = await ctx.runQuery(api.jobs.board, { jobId });
    if (!job) throw new Error("no job");
    if (job.job.inboxId) {
      return { inboxId: job.job.inboxId, address: job.job.inboxAddress, reused: true };
    }

    // Inbox allowances are finite. Reuse one we already made for Bidzy
    // before asking for another.
    const existing = await am("/inboxes");
    const list = existing.inboxes ?? existing.data ?? existing;
    const mine = Array.isArray(list)
      ? list.find((i: any) =>
          String(i.inbox_id ?? i.address ?? "").startsWith("bidzy-")
        )
      : null;

    if (mine) {
      const inboxId = mine.inbox_id ?? mine.inboxId ?? mine.address;
      const address = mine.address ?? mine.email ?? inboxId;
      await ctx.runMutation(api.jobs.setInbox, {
        jobId,
        inboxId: String(inboxId),
        inboxAddress: String(address),
      });
      return { inboxId, address, reused: true };
    }

    const uname =
      username ??
      `bidzy-${job.job.trade}-${String(jobId).slice(-6)}`.toLowerCase();

    const inbox = await am("/inboxes", {
      method: "POST",
      body: JSON.stringify({
        username: uname,
        display_name: `Bidzy - ${job.job.name}`,
        client_id: `bidzy-job-${jobId}`,
      }),
    });

    const inboxId = inbox.inbox_id ?? inbox.inboxId;
    const address = inbox.address ?? inbox.email ?? inboxId;

    await ctx.runMutation(api.jobs.setInbox, {
      jobId,
      inboxId: String(inboxId),
      inboxAddress: String(address),
    });

    return { inboxId, address, reused: false };
  },
});

'''
s = s.replace(old, new)
open(p, "w").write(s)
print("ensureInbox reuses existing inboxes")
PY
