#!/bin/bash
# Lock the header grid, stop chips wrapping, seed sample mail for dev.
set -e
[ -d convex/quoteEngine ] || { echo "Run from the bidzy project root."; exit 1; }

# ---- 1. chips never wrap; header cells are a fixed stack ----
python3 - << 'PY'
p = "src/components/ui.tsx"
s = open(p).read()
s = s.replace(
  'className={`inline-flex items-center h-[22px] px-2 rounded-md text-[11px] font-medium leading-none ${tones[tone]}`}',
  'className={`inline-flex items-center h-[22px] px-2 rounded-md text-[11px] font-medium leading-none whitespace-nowrap shrink-0 ${tones[tone]}`}'
)
open(p, "w").write(s)
print("chips no longer wrap")
PY

# ---- 2. board header: fixed-height name row + fixed-height chip row ----
python3 - << 'PY'
p = "src/components/Board.tsx"
s = open(p).read()

old_head = s[s.index("          <thead>"):s.index("          </thead>")]
new_head = '''          <thead>
            <tr>
              <th className="align-bottom text-left pb-5">
                <div className="h-5" />
                <div className="h-[26px] flex items-end">
                  <span className="text-[12px] font-medium text-[#5A5A5A]">
                    Company
                  </span>
                </div>
              </th>
              {rows.map((r) => (
                <th key={r.firmId} className="align-bottom text-left pb-5 pl-5">
                  <div
                    className={`h-5 text-[14px] font-semibold leading-5 truncate ${
                      r.quote?.stale ? "text-[#5A5A5A]" : "text-[#EDEDED]"
                    }`}
                  >
                    {r.firmName}
                  </div>
                  <div className="h-[26px] pt-1 flex items-center gap-1.5 overflow-hidden">
                    <Status row={r} />
                    {r.licenceStatus === "expired" && (
                      <Chip tone="bad">licence expired</Chip>
                    )}
                  </div>
                </th>
              ))}
            </tr>
'''
s = s.replace(old_head, new_head)
open(p, "w").write(s)
print("board header locked to a fixed stack")
PY

# ---- 3. stat cards: chip on its own line so nothing wraps ----
python3 - << 'PY'
p = "src/components/Stats.tsx"
s = open(p).read()
s = s.replace(
'''      <div className="h-[22px] flex items-center gap-2 mt-3">
        {chip}
        {foot && <span className="text-[12.5px] text-[#A1A1A1] truncate">{foot}</span>}
      </div>''',
'''      <div className="mt-3 space-y-2">
        <div className="h-[18px] text-[12.5px] text-[#A1A1A1] truncate">
          {foot}
        </div>
        <div className="h-[22px] flex items-center">{chip}</div>
      </div>'''
)
open(p, "w").write(s)
print("stat cards stacked")
PY

# ---- 4. sample mail + docs so every page has something in dev ----
cat > convex/demo.ts << 'EOF'
import { mutation } from "./_generated/server";
import { components } from "./_generated/api";

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
    for (const i of invs) await ctx.db.patch(i._id, { status: "sent", chaseCount: 0 });
    const msgs = await ctx.db.query("messages").collect();
    for (const m of msgs) await ctx.db.delete(m._id);
    return { reset: invs.length };
  },
});

// Fills the inbox with a believable thread so the Inbox and Documents
// pages have something to show without sending real mail.
export const sampleMail = mutation({
  args: {},
  handler: async (ctx) => {
    const job = await ctx.db.query("jobs").first();
    if (!job) throw new Error("seed a project first");
    const firms = await ctx.db.query("firms").collect();
    const inbox = job.inboxAddress ?? "bidzy-roofing-demo@agentmail.to";
    const MIN = 60000;
    const now = Date.now();

    const old = await ctx.db
      .query("messages")
      .withIndex("by_job", (q) => q.eq("jobId", job._id))
      .collect();
    for (const m of old) await ctx.db.delete(m._id);

    const invite = (name) =>
      [
        `Hi ${name},`,
        ``,
        `We're pricing ${job.name} at 42 Marlow Street and would like your number.`,
        ``,
        `Scope: ${job.description ?? job.name}`,
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

    for (let i = 0; i < firms.length; i++) {
      const f = firms[i];
      await ctx.db.insert("messages", {
        jobId: job._id,
        firmId: f._id,
        direction: "out",
        subject: `Request for pricing - ${job.name}, 42 Marlow Street`,
        body: invite(f.name),
        fromAddress: inbox,
        toAddress: f.email,
        attachments: [],
        kind: "invitation",
        createdAt: now - 400 * MIN + i * MIN,
      });
    }

    const replies = [
      [
        "Apex Roofing",
        "Re: Request for pricing - Roof replacement",
        `Morning,\n\nHappy to price this.\n\nTotal: $14,200\n\nBreakdown:\nTear-off and disposal $2,400\nAsphalt shingle, supply $6,100\nLabour $4,500\nDelivery and skip hire $1,200\n\nIncludes: removal and disposal, delivery, skip hire, sales tax, 5 year workmanship warranty\nExcludes: gutter replacement\n\nPrice holds 30 days.\n\nRegards,\nDanny, Apex Roofing`,
        120,
      ],
      [
        "Crown Roof Systems",
        "Re: Request for pricing - Roof replacement",
        `Our price is $11,900.\n\nExcludes: removal and disposal, delivery, skip hire, sales tax\nIncludes: labour\n\nCustomer to arrange a skip on site before we start.\n\nCrown Roof Systems`,
        95,
      ],
      [
        "PrimeBuild",
        "Re: Request for pricing - Roof replacement",
        `Hello,\n\n$13,450 all in for the roof. Quote attached.\n\nDoes not include skip hire or gutters.\n\nPrimeBuild`,
        60,
      ],
      [
        "Skyline Exteriors",
        "Re: Request for pricing - Roof replacement",
        `Hi,\n\nQuote attached as a PDF.\n\nTotal: $15,800 in natural slate. We can also do the same works in asphalt shingle at $13,900 if that suits better.\n\nIncludes: removal and disposal, delivery, crane hire, sales tax, temporary protection, 10 year workmanship warranty\nExcludes: night work, gutter replacement\n\nThanks,\nMarian, Skyline Exteriors`,
        20,
      ],
    ];

    for (const [name, subject, body, minsAgo] of replies) {
      const f = firms.find((x) => x.name.startsWith(String(name).split(" ")[0]));
      if (!f) continue;
      await ctx.db.insert("messages", {
        jobId: job._id,
        firmId: f._id,
        direction: "in",
        subject: String(subject),
        body: String(body),
        fromAddress: f.email,
        toAddress: inbox,
        attachments:
          name === "Skyline Exteriors"
            ? [{ filename: "quote-skyline-slate.pdf", url: "/quotes/quote-skyline-slate.pdf", contentType: "application/pdf" }]
            : name === "PrimeBuild"
            ? [{ filename: "primebuild-quote.pdf", url: "", contentType: "application/pdf" }]
            : [],
        kind: "quote",
        createdAt: now - Number(minsAgo) * MIN,
      });
      await ctx.db.insert("events", {
        projectId: job.projectId,
        jobId: job._id,
        type: "reply_received",
        summary: `Reply from ${f.name}`,
        createdAt: now - Number(minsAgo) * MIN,
      });
    }

    return { messages: firms.length + replies.length };
  },
});
EOF

# ---- 5. richer empty states that say what to do ----
python3 - << 'PY'
p = "src/pages/InboxPage.tsx"
s = open(p).read()
s = s.replace(
  "<Empty>No email yet.</Empty>",
  '<Empty>No email yet. Use \u201cAsk for prices\u201d above and the replies land here.</Empty>'
)
open(p, "w").write(s)

p = "src/pages/DocsPage.tsx"
s = open(p).read()
s = s.replace(
  "<Empty>Nothing read yet.</Empty>",
  '<Empty>Nothing read yet. Paste a quote PDF above, or let one arrive by email.</Empty>'
)
open(p, "w").write(s)
print("empty states now tell you what to do")
PY

echo ""
echo "Now run:"
echo "  npx convex dev --once"
echo "  npx convex run seed:demo"
echo "  npx convex run demo:sampleMail"
