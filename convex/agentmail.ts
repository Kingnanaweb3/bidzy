"use node";
import { action } from "./_generated/server";
import { internal, api } from "./_generated/api";
import { v } from "convex/values";

const BASE = "https://api.agentmail.to/v0";

function key() {
  const k = process.env.AGENTMAIL_API_KEY;
  if (!k) throw new Error("AGENTMAIL_API_KEY is not set on the Convex deployment");
  return k;
}

async function am(path, opts = {}) {
  const res = await fetch(`${BASE}${path}`, {
    ...opts,
    headers: {
      Authorization: `Bearer ${key()}`,
      "Content-Type": "application/json",
      ...(opts.headers ?? {}),
    },
  });
  const body = await res.text();
  if (!res.ok) throw new Error(`AgentMail ${res.status} ${path}: ${body}`);
  return body ? JSON.parse(body) : {};
}

// Create (or reuse) an inbox dedicated to one job.
export const ensureInbox = action({
  args: { jobId: v.id("jobs"), username: v.optional(v.string()) },
  handler: async (ctx, { jobId, username }) => {
    const job = await ctx.runQuery(api.jobs.board, { jobId });
    if (!job) throw new Error("no job");
    if (job.job.inboxId) {
      return { inboxId: job.job.inboxId, address: job.job.inboxAddress, reused: true };
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

// Register the Convex HTTP endpoint as the webhook target.
export const registerWebhook = action({
  args: { url: v.string() },
  handler: async (_ctx, { url }) => {
    const res = await am("/webhooks", {
      method: "POST",
      body: JSON.stringify({
        url,
        event_types: ["message.received"],
        client_id: "bidzy-inbound",
      }),
    });
    return res;
  },
});

export const listInboxes = action({
  args: {},
  handler: async () => am("/inboxes"),
});

// Email every firm that hasn't quoted yet.
export const sendInvitations = action({
  args: { jobId: v.id("jobs"), chase: v.optional(v.boolean()) },
  handler: async (ctx, { jobId, chase }) => {
    const data = await ctx.runQuery(api.jobs.board, { jobId });
    if (!data) throw new Error("no job");

    let inboxId = data.job.inboxId;
    let fromAddress = data.job.inboxAddress;
    if (!inboxId) {
      const made = await ctx.runAction(api.agentmail.ensureInbox, { jobId });
      inboxId = made.inboxId;
      fromAddress = made.address;
    }

    const targets = data.rows.filter((r) =>
      chase ? !r.quote : r.status === "sent" && !r.quote
    );

    const sent = [];
    for (const row of targets) {
      if (!row.firmEmail || row.firmEmail.endsWith("@example.com")) continue;

      const subject = chase
        ? `Following up - pricing for ${data.job.name}`
        : `Request for pricing - ${data.job.name}, 42 Marlow Street`;

      const text = chase
        ? [
            `Hi ${row.firmName},`,
            ``,
            `Just following up on pricing for ${data.job.name} at 42 Marlow Street.`,
            `If you're not bidding this one, a one-line reply is all we need and we'll stop chasing.`,
            ``,
            `If you are, please send your price along with anything you're excluding.`,
            ``,
            `Thanks,`,
            `Bidzy, on behalf of the homeowner`,
          ].join("\n")
        : [
            `Hi ${row.firmName},`,
            ``,
            `We're pricing ${data.job.name} at 42 Marlow Street and would like your number.`,
            ``,
            `Scope: ${data.job.description ?? data.job.name}`,
            ``,
            `Please reply with:`,
            `  Total: $0,000`,
            `  Excludes: anything not in your price`,
            `  Includes: anything worth calling out`,
            ``,
            `A plain reply is fine - we read the email itself, no forms.`,
            ``,
            `Thanks,`,
            `Bidzy, on behalf of the homeowner`,
          ].join("\n");

      const res = await am(`/inboxes/${inboxId}/messages/send`, {
        method: "POST",
        body: JSON.stringify({
          to: row.firmEmail,
          subject,
          text,
          labels: [`job:${jobId}`, chase ? "chase" : "invitation"],
        }),
      });

      await ctx.runMutation(internal.mail.recordOutbound, {
        jobId,
        firmId: row.firmId,
        subject,
        body: text,
        fromAddress: String(fromAddress),
        toAddress: row.firmEmail,
        messageId: res.message_id ?? res.messageId,
        threadId: res.thread_id ?? res.threadId,
        kind: chase ? "chase" : "invitation",
      });

      sent.push(row.firmName);
    }

    return { sent, count: sent.length, from: fromAddress };
  },
});

// Ask firms whose quotes went stale to confirm their price.
export const requestReprice = action({
  args: { jobId: v.id("jobs") },
  handler: async (ctx, { jobId }) => {
    const data = await ctx.runQuery(api.jobs.board, { jobId });
    if (!data?.job.inboxId) throw new Error("no inbox for this job yet");

    const stale = data.rows.filter((r) => r.quote?.stale);
    const sent = [];

    for (const row of stale) {
      if (!row.firmEmail || row.firmEmail.endsWith("@example.com")) continue;

      const subject = `The job has changed - does your price still hold?`;
      const text = [
        `Hi ${row.firmName},`,
        ``,
        `The homeowner has changed the job since you sent your price.`,
        `Your price of $${row.quote.total?.toLocaleString()} was for the original job.`,
        ``,
        `Does that number still hold? If not, please send a revised one.`,
        ``,
        `Thanks,`,
        `Bidzy, on behalf of the homeowner`,
      ].join("\n");

      await am(`/inboxes/${data.job.inboxId}/messages/send`, {
        method: "POST",
        body: JSON.stringify({
          to: row.firmEmail,
          subject,
          text,
          labels: [`job:${jobId}`, "reprice"],
        }),
      });

      await ctx.runMutation(internal.mail.recordOutbound, {
        jobId,
        firmId: row.firmId,
        subject,
        body: text,
        fromAddress: String(data.job.inboxAddress),
        toAddress: row.firmEmail,
        kind: "reprice",
      });

      sent.push(row.firmName);
    }

    return { sent, count: sent.length };
  },
});
