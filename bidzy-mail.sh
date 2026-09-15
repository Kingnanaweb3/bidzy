#!/bin/bash
# Bidzy — AgentMail integration: real outbound invitations, real inbound replies,
# quote extraction, live thread view. Run from project root.
set -e
[ -d convex ] || { echo "Run from the bidzy project root."; exit 1; }

echo "Writing AgentMail integration..."

# ---------------- internal mutations for mail ----------------
cat > convex/mail.ts << 'EOF'
import { internalMutation, mutation, query } from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";

export const threadsByJob = query({
  args: { jobId: v.id("jobs") },
  handler: async (ctx, { jobId }) => {
    const msgs = await ctx.db
      .query("messages")
      .withIndex("by_job", (q) => q.eq("jobId", jobId))
      .order("desc")
      .take(50);

    const firmIds = [...new Set(msgs.map((m) => m.firmId).filter(Boolean))];
    const firms = await Promise.all(firmIds.map((id) => ctx.db.get(id)));
    const nameById = new Map(firms.filter(Boolean).map((f) => [f._id, f.name]));

    return msgs.map((m) => ({
      ...m,
      firmName: m.firmId ? nameById.get(m.firmId) ?? "Unknown" : "Unknown",
    }));
  },
});

export const recordOutbound = internalMutation({
  args: {
    jobId: v.id("jobs"),
    firmId: v.id("firms"),
    subject: v.string(),
    body: v.string(),
    fromAddress: v.string(),
    toAddress: v.string(),
    messageId: v.optional(v.string()),
    threadId: v.optional(v.string()),
    kind: v.string(),
  },
  handler: async (ctx, args) => {
    await ctx.db.insert("messages", {
      ...args,
      direction: "out",
      attachments: [],
      createdAt: Date.now(),
    });

    const inv = await ctx.db
      .query("invitations")
      .withIndex("by_job", (q) => q.eq("jobId", args.jobId))
      .collect();
    const mine = inv.find((i) => i.firmId === args.firmId);
    if (mine) {
      await ctx.db.patch(mine._id, {
        threadId: args.threadId,
        lastChasedAt: args.kind === "chase" ? Date.now() : mine.lastChasedAt,
        chaseCount: args.kind === "chase" ? mine.chaseCount + 1 : mine.chaseCount,
      });
    }

    const job = await ctx.db.get(args.jobId);
    const firm = await ctx.db.get(args.firmId);
    if (job) {
      await ctx.db.insert("events", {
        projectId: job.projectId,
        jobId: args.jobId,
        type: args.kind === "chase" ? "chase_sent" : "invite_sent",
        summary:
          args.kind === "chase"
            ? `Followed up with ${firm?.name ?? "a firm"} - no reply yet`
            : `Emailed ${firm?.name ?? "a firm"} asking for a price`,
        createdAt: Date.now(),
      });
    }
  },
});

// Inbound: match sender to a firm, store the message, try to read a quote.
export const handleInbound = internalMutation({
  args: {
    fromAddress: v.string(),
    toAddress: v.string(),
    subject: v.optional(v.string()),
    text: v.string(),
    messageId: v.optional(v.string()),
    threadId: v.optional(v.string()),
    attachments: v.optional(
      v.array(
        v.object({
          filename: v.string(),
          url: v.string(),
          contentType: v.optional(v.string()),
        })
      )
    ),
  },
  handler: async (ctx, args) => {
    const addr = args.fromAddress.toLowerCase().trim();
    const firm = await ctx.db
      .query("firms")
      .withIndex("by_email", (q) => q.eq("email", addr))
      .first();

    // find the job this thread belongs to
    let jobId = null;
    if (firm) {
      const invs = await ctx.db
        .query("invitations")
        .withIndex("by_firm", (q) => q.eq("firmId", firm._id))
        .collect();
      const byThread = invs.find((i) => i.threadId === args.threadId);
      jobId = (byThread ?? invs[0])?.jobId ?? null;
    }
    if (!jobId) {
      const anyJob = await ctx.db.query("jobs").first();
      jobId = anyJob?._id ?? null;
    }
    if (!jobId) return { ignored: true };

    await ctx.db.insert("messages", {
      jobId,
      firmId: firm?._id,
      direction: "in",
      subject: args.subject,
      body: args.text,
      fromAddress: addr,
      toAddress: args.toAddress,
      messageId: args.messageId,
      threadId: args.threadId,
      attachments: args.attachments ?? [],
      kind: "reply",
      createdAt: Date.now(),
    });

    const job = await ctx.db.get(jobId);
    if (job) {
      await ctx.db.insert("events", {
        projectId: job.projectId,
        jobId,
        type: "reply_received",
        summary: `Reply from ${firm?.name ?? addr}`,
        createdAt: Date.now(),
      });
    }

    if (!firm) return { stored: true, matched: false };

    // mark replied
    const invs = await ctx.db
      .query("invitations")
      .withIndex("by_firm", (q) => q.eq("firmId", firm._id))
      .collect();
    const inv = invs.find((i) => i.jobId === jobId);
    if (inv && inv.status !== "quoted") {
      await ctx.db.patch(inv._id, { status: "replied" });
    }

    // try to read a price out of the body
    const parsed = extractQuote(args.text);
    if (parsed.total == null) return { stored: true, matched: true, quoted: false };

    const existing = await ctx.db
      .query("quotes")
      .withIndex("by_job", (q) => q.eq("jobId", jobId))
      .collect();
    const prior = existing.find((q) => q.firmId === firm._id);

    const project = await ctx.db.get(job.projectId);
    const payload = {
      total: parsed.total,
      lineItems: parsed.lineItems,
      exclusions: parsed.exclusions,
      inclusions: parsed.inclusions,
      rawText: args.text.slice(0, 4000),
      needsReview: parsed.needsReview,
      revision: project?.revision ?? 1,
      stale: false,
      staleReason: undefined,
      receivedAt: Date.now(),
    };

    if (prior) {
      await ctx.db.patch(prior._id, payload);
    } else {
      await ctx.db.insert("quotes", {
        jobId,
        firmId: firm._id,
        invitationId: inv?._id,
        currency: "USD",
        scopeTags: ["glazing-spec", "exterior-windows"],
        ...payload,
      });
    }
    if (inv) await ctx.db.patch(inv._id, { status: "quoted" });

    await ctx.db.insert("events", {
      projectId: job.projectId,
      jobId,
      type: "quote_parsed",
      summary: `Read ${firm.name}'s price: $${parsed.total.toLocaleString()}${
        parsed.exclusions.length
          ? ` - excludes ${parsed.exclusions.join(", ")}`
          : ""
      }`,
      createdAt: Date.now() + 1,
    });

    return { stored: true, matched: true, quoted: true };
  },
});

// Heuristic reader. Firecrawl /parse will replace this for PDFs.
function extractQuote(text) {
  const clean = text.replace(/\r/g, "");
  const lineItems = [];
  const exclusions = [];
  const inclusions = [];
  let total = null;
  let needsReview = false;

  const moneyRe = /\$\s?([\d,]+(?:\.\d{2})?)/g;
  const num = (s) => Number(String(s).replace(/,/g, ""));

  // explicit total wins
  const totalLine = clean
    .split("\n")
    .find((l) => /\b(total|lump sum|all[- ]in|our price|quote)\b/i.test(l) && /\$/.test(l));
  if (totalLine) {
    const m = [...totalLine.matchAll(moneyRe)];
    if (m.length) total = num(m[m.length - 1][1]);
  }

  for (const line of clean.split("\n")) {
    const t = line.trim();
    if (!t) continue;

    if (/^(excl|excludes?|not included|we exclude)/i.test(t)) {
      t.replace(/^[^:]*:?/, "")
        .split(/[,;]/)
        .map((s) => s.trim())
        .filter(Boolean)
        .forEach((s) => exclusions.push(titleCase(s)));
      continue;
    }
    if (/^(incl|includes?|included)/i.test(t)) {
      t.replace(/^[^:]*:?/, "")
        .split(/[,;]/)
        .map((s) => s.trim())
        .filter(Boolean)
        .forEach((s) => inclusions.push(titleCase(s)));
      continue;
    }

    const m = [...t.matchAll(moneyRe)];
    if (m.length && !/\b(total|lump sum|all[- ]in)\b/i.test(t)) {
      const label = t.split("$")[0].replace(/[-:\u2013]\s*$/, "").trim();
      if (label.length > 2 && label.length < 80) {
        lineItems.push({ label: titleCase(label), amount: num(m[0][1]) });
      }
    }
  }

  if (total == null && lineItems.length) {
    total = lineItems.reduce((a, b) => a + (b.amount ?? 0), 0);
    needsReview = true;
  }
  if (total == null) {
    const all = [...clean.matchAll(moneyRe)].map((m) => num(m[1]));
    if (all.length) {
      total = Math.max(...all);
      needsReview = true;
    }
  }
  if (!exclusions.length) needsReview = true;

  return { total, lineItems, exclusions, inclusions, needsReview };
}

function titleCase(s) {
  const t = s.trim().replace(/\.$/, "");
  return t.charAt(0).toUpperCase() + t.slice(1);
}
EOF

# ---------------- actions that call AgentMail ----------------
cat > convex/agentmail.ts << 'EOF'
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
        : `Request for pricing - ${data.job.name}, Riverside Medical Clinic`;

      const text = chase
        ? [
            `Hi ${row.firmName},`,
            ``,
            `Just following up on pricing for ${data.job.name} at Riverside Medical Clinic.`,
            `If you're not bidding this one, a one-line reply is all we need and we'll stop chasing.`,
            ``,
            `If you are, please send your price along with anything you're excluding.`,
            ``,
            `Thanks,`,
            `Bidzy, on behalf of Riverside Health Partners`,
          ].join("\n")
        : [
            `Hi ${row.firmName},`,
            ``,
            `We're pricing ${data.job.name} at Riverside Medical Clinic and would like your number.`,
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
            `Bidzy, on behalf of Riverside Health Partners`,
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

      const subject = `Design change - does your price for ${data.job.name} still hold?`;
      const text = [
        `Hi ${row.firmName},`,
        ``,
        `The architect has issued a change to the glazing spec since you priced this job.`,
        `Your quote of $${row.quote.total?.toLocaleString()} was against the previous drawings.`,
        ``,
        `Does that number still hold? If not, please send a revised one.`,
        ``,
        `Thanks,`,
        `Bidzy, on behalf of Riverside Health Partners`,
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
EOF

# ---------------- webhook receiver on convex.site ----------------
cat > convex/http.ts << 'EOF'
import { httpRouter } from "convex/server";
import { httpAction } from "./_generated/server";
import { internal } from "./_generated/api";

const http = httpRouter();

http.route({
  path: "/agentmail/webhook",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    let payload;
    try {
      payload = await request.json();
    } catch {
      return new Response("bad json", { status: 400 });
    }

    const type = payload.event_type ?? payload.type;
    if (type && type !== "message.received") {
      return new Response("ignored", { status: 200 });
    }

    const m = payload.message ?? payload.data ?? payload;
    const from =
      m.from_address ?? m.from ?? m.sender ?? m.envelope_from ?? "";
    const to = Array.isArray(m.to) ? m.to[0] : m.to ?? m.to_address ?? "";
    const text =
      m.extracted_text ?? m.text ?? m.plain_text ?? m.body ?? m.snippet ?? "";

    const fromEmail = String(from).match(/<([^>]+)>/)?.[1] ?? String(from);

    await ctx.runMutation(internal.mail.handleInbound, {
      fromAddress: fromEmail,
      toAddress: String(to),
      subject: m.subject,
      text: String(text),
      messageId: m.message_id ?? m.id,
      threadId: m.thread_id,
      attachments: (m.attachments ?? []).map((a) => ({
        filename: a.filename ?? a.name ?? "attachment",
        url: a.url ?? a.download_url ?? "",
        contentType: a.content_type ?? a.contentType,
      })),
    });

    return new Response("ok", { status: 200 });
  }),
});

// quick health check
http.route({
  path: "/agentmail/webhook",
  method: "GET",
  handler: httpAction(async () => new Response("bidzy webhook alive")),
});

export default http;
EOF

# ---------------- UI: inbox panel + send controls + thread list ----------------
cat > src/components/Inbox.tsx << 'EOF'
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
            This job's inbox
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
            {busy === "invite" ? "Sending..." : "Ask firms for a price"}
          </button>
          <button
            onClick={() => run("chase", () => send({ jobId, chase: true }))}
            disabled={!!busy}
            className="text-xs font-medium border border-stone-300 px-3 py-2 rounded-md hover:bg-stone-50 disabled:opacity-40"
          >
            {busy === "chase" ? "Sending..." : "Chase non-responders"}
          </button>
          <button
            onClick={() => run("reprice", () => reprice({ jobId }))}
            disabled={!!busy}
            className="text-xs font-medium border border-stone-300 px-3 py-2 rounded-md hover:bg-stone-50 disabled:opacity-40"
          >
            {busy === "reprice" ? "Sending..." : "Ask stale firms to reprice"}
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
            No email yet. Create the inbox, then ask the firms for a price.
          </p>
        )}
      </div>
    </section>
  );
}
EOF

cat > src/App.tsx << 'EOF'
import { useQuery } from "convex/react";
import { api } from "../convex/_generated/api";
import Board from "./components/Board";
import Feed from "./components/Feed";
import Header from "./components/Header";
import Inbox from "./components/Inbox";

export default function App() {
  const projects = useQuery(api.projects.list);
  const project = projects?.[0];
  const jobs = useQuery(
    api.jobs.listByProject,
    project ? { projectId: project._id } : "skip"
  );
  const job = jobs?.[0];

  if (projects === undefined) return <Splash text="Loading" />;
  if (!project)
    return <Splash text="No project yet - run: npx convex run seed:demo" />;

  return (
    <div className="min-h-screen">
      <Header project={project} />
      <main className="mx-auto max-w-[1400px] px-6 py-8 grid grid-cols-1 xl:grid-cols-[1fr_320px] gap-8">
        <div>
          {job ? (
            <>
              <Board jobId={job._id} />
              <Inbox job={job} jobId={job._id} />
            </>
          ) : (
            <Splash text="No job yet" />
          )}
        </div>
        <Feed projectId={project._id} />
      </main>
    </div>
  );
}

function Splash({ text }) {
  return (
    <div className="min-h-screen grid place-items-center text-stone-400 text-sm">
      {text}
    </div>
  );
}
EOF

# ---------------- helper: set real firm emails ----------------
cat > convex/firmsAdmin.ts << 'EOF'
import { mutation } from "./_generated/server";
import { v } from "convex/values";

// Point the seeded firms at addresses you actually control.
export const setEmails = mutation({
  args: { pairs: v.array(v.object({ name: v.string(), email: v.string() })) },
  handler: async (ctx, { pairs }) => {
    const firms = await ctx.db.query("firms").collect();
    let updated = 0;
    for (const p of pairs) {
      const f = firms.find((x) =>
        x.name.toLowerCase().startsWith(p.name.toLowerCase())
      );
      if (f) {
        await ctx.db.patch(f._id, { email: p.email.toLowerCase() });
        updated++;
      }
    }
    return { updated };
  },
});
EOF

echo ""
echo "Done. Next steps printed by the script:"
echo "  1. npx convex env list          (confirm AGENTMAIL_API_KEY is set)"
echo "  2. set real firm emails         (see instructions)"
echo "  3. register the webhook"
