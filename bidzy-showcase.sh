#!/bin/bash
# A full, believable demo state: 5 companies, threads, chases, a decline,
# documents, and a week of activity.
set -e
[ -d convex/quoteEngine ] || { echo "Run from the bidzy project root."; exit 1; }

# --- chips must not be clipped in the board header ---
python3 - << 'PY'
p = "src/components/Board.tsx"
s = open(p).read()
s = s.replace(
  'className="h-[26px] pt-1 flex items-center gap-1.5 overflow-hidden"',
  'className="h-[26px] pt-1 flex items-center gap-1.5"'
)
s = s.replace("<Chip tone=\"bad\">licence expired</Chip>", "<Chip tone=\"bad\">expired</Chip>")
open(p, "w").write(s)
print("chips no longer clipped")
PY

python3 - << 'PY'
p = "convex/demo.ts"
s = open(p).read()
s += '''

// A full demo state. Five companies, real-looking threads, chases, a
// decline, documents and a week of activity.
export const showcase = mutation({
  args: {},
  handler: async (ctx) => {
    for (const t of ["messages", "events", "invitations", "firms", "jobs", "addenda", "projects"]) {
      const rows = await ctx.db.query(t).collect();
      for (const r of rows) await ctx.db.delete(r._id);
    }
    await ctx.runMutation(components.quoteEngine.quotes.clearAll, {});

    const DAY = 86400000;
    const HOUR = 3600000;
    const MIN = 60000;
    const now = Date.now();

    const projectId = await ctx.db.insert("projects", {
      name: "Roof replacement",
      client: "42 Marlow Street",
      scope: ["asphalt-shingle"],
      scopeNote: "Asphalt shingle, full tear-off and replacement",
      revision: 1,
      createdAt: now - 9 * DAY,
    });

    const jobId = await ctx.db.insert("jobs", {
      projectId,
      name: "Roof replacement",
      trade: "roofing",
      description:
        "Full tear-off and replacement of the roof on a 3-bedroom house. Materials, labour, removal and disposal.",
      inboxAddress: "bidzy-roofing-8egxzd@agentmail.to",
      inboxId: "bidzy-roofing-8egxzd@agentmail.to",
      revision: 1,
      createdAt: now - 9 * DAY,
    });

    const spec = [
      { name: "Apex Roofing", email: "hello@apexroofing.example", licenceStatus: "valid" },
      { name: "Crown Roof Systems", email: "quotes@crownroof.example", licenceStatus: "valid" },
      { name: "PrimeBuild", email: "info@primebuild.example", licenceStatus: "expired" },
      { name: "Skyline Exteriors", email: "marian@skylineexteriors.example", licenceStatus: "valid" },
      { name: "Halewood Roofing", email: "office@halewood.example", licenceStatus: "valid" },
    ];
    const ids = {};
    for (const f of spec) {
      ids[f.name] = await ctx.db.insert("firms", {
        ...f,
        trade: "roofing",
        licenceCheckedAt: now - 8 * DAY,
      });
    }

    const inbox = "bidzy-roofing-8egxzd@agentmail.to";
    const ev = (type, summary, at) =>
      ctx.db.insert("events", { projectId, jobId, type, summary, createdAt: at });
    const msg = (name, direction, subject, body, at, attachments = []) =>
      ctx.db.insert("messages", {
        jobId,
        firmId: ids[name],
        direction,
        subject,
        body,
        fromAddress: direction === "out" ? inbox : spec.find((s) => s.name === name).email,
        toAddress: direction === "out" ? spec.find((s) => s.name === name).email : inbox,
        attachments,
        kind: direction === "out" ? "invitation" : "quote",
        createdAt: at,
      });

    const invite = (name) =>
      [
        `Hi ${name},`,
        ``,
        `We're pricing a full roof replacement at 42 Marlow Street and would like your number.`,
        ``,
        `Scope: full tear-off and replacement on a 3-bedroom house. Materials, labour, removal and disposal.`,
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
      ].join("\\n");

    // day 9: invitations
    let i = 0;
    for (const f of spec) {
      await msg(f.name, "out", "Request for pricing - Roof replacement, 42 Marlow Street", invite(f.name), now - 8 * DAY + i * 4 * MIN);
      i++;
    }
    await ev("invite_sent", "Asked 5 roofing companies for a price", now - 8 * DAY);

    // day 7: first reply, Apex
    await msg(
      "Apex Roofing", "in", "Re: Request for pricing - Roof replacement",
      `Morning,\\n\\nHappy to price this.\\n\\nTotal: $14,200\\n\\nTear-off and disposal $2,400\\nAsphalt shingle, supply $6,100\\nLabour $4,500\\nDelivery and skip hire $1,200\\n\\nIncludes: removal and disposal, delivery, skip hire, sales tax, 5 year workmanship warranty\\nExcludes: gutter replacement\\n\\nPrice holds 30 days.\\n\\nRegards,\\nDanny, Apex Roofing`,
      now - 6 * DAY - 3 * HOUR
    );
    await ev("reply_received", "Reply from Apex Roofing", now - 6 * DAY - 3 * HOUR);
    await ev("quote_parsed", "Read Apex Roofing's price: $14,200 - excludes Gutter replacement", now - 6 * DAY - 3 * HOUR + MIN);

    // day 5: chase the quiet ones
    for (const n of ["Crown Roof Systems", "PrimeBuild", "Skyline Exteriors", "Halewood Roofing"]) {
      await msg(n, "out", "Following up - pricing for Roof replacement",
        `Hi ${n},\\n\\nJust following up on pricing for the roof at 42 Marlow Street.\\n\\nIf you're not bidding this one, a one-line reply is all we need and we'll stop chasing.\\n\\nThanks,\\nBidzy, on behalf of the homeowner`,
        now - 5 * DAY);
    }
    await ev("chase_sent", "Followed up with 4 companies - no reply yet", now - 5 * DAY);

    // day 4: Crown replies
    await msg(
      "Crown Roof Systems", "in", "Re: Request for pricing - Roof replacement",
      `Our price is $11,900.\\n\\nExcludes: removal and disposal, delivery, skip hire, sales tax\\nIncludes: labour\\n\\nCustomer to arrange a skip on site before we start.\\n\\nCrown Roof Systems`,
      now - 4 * DAY - 5 * HOUR
    );
    await ev("reply_received", "Reply from Crown Roof Systems", now - 4 * DAY - 5 * HOUR);
    await ev("quote_parsed", "Read Crown Roof Systems's price: $11,900 - excludes Removal and disposal, Delivery, Skip hire, Sales tax", now - 4 * DAY - 5 * HOUR + MIN);

    // day 3: Halewood declines
    await msg(
      "Halewood Roofing", "in", "Re: Following up - pricing for Roof replacement",
      `Thanks for thinking of us - we're booked solid until March so we'll pass on this one.\\n\\nGood luck with it.\\n\\nHalewood Roofing`,
      now - 3 * DAY
    );
    await ev("reply_received", "Halewood Roofing declined - booked until March", now - 3 * DAY);

    // day 2: PrimeBuild, vague, expired licence
    await msg(
      "PrimeBuild", "in", "Re: Request for pricing - Roof replacement",
      `Hello,\\n\\n$13,450 all in for the roof. Quote attached.\\n\\nDoes not include skip hire or gutters.\\n\\nPrimeBuild`,
      now - 2 * DAY - 2 * HOUR,
      [{ filename: "primebuild-quote.pdf", url: "/quotes/quote-crown-asphalt.pdf", contentType: "application/pdf" }]
    );
    await ev("reply_received", "Reply from PrimeBuild, with a PDF", now - 2 * DAY - 2 * HOUR);
    await ev("quote_parsed", "Read PrimeBuild's price: $13,450 - no breakdown given, worth checking", now - 2 * DAY - 2 * HOUR + MIN);
    await ev("licence_flag", "PrimeBuild's licence shows as expired on the public register", now - 2 * DAY - HOUR);

    // yesterday: Skyline, with the slate option
    await msg(
      "Skyline Exteriors", "in", "Re: Request for pricing - Roof replacement",
      `Hi,\\n\\nQuote attached as a PDF.\\n\\nTotal: $15,800 in natural slate. We can also do the same works in asphalt shingle at $13,900 if that suits better.\\n\\nIncludes: removal and disposal, delivery, crane hire, sales tax, temporary protection, 10 year workmanship warranty\\nExcludes: night work, gutter replacement\\n\\nThanks,\\nMarian, Skyline Exteriors`,
      now - 20 * HOUR,
      [{ filename: "quote-skyline-slate.pdf", url: "/quotes/quote-skyline-slate.pdf", contentType: "application/pdf" }]
    );
    await ev("reply_received", "Reply from Skyline Exteriors, with a PDF", now - 20 * HOUR);
    await ev("quote_parsed", "Read quote-skyline-slate.pdf - $15,800, priced in slate as well as asphalt", now - 20 * HOUR + MIN);

    // invitations + statuses
    const status = {
      "Apex Roofing": "quoted",
      "Crown Roof Systems": "quoted",
      "PrimeBuild": "quoted",
      "Skyline Exteriors": "quoted",
      "Halewood Roofing": "declined",
    };
    const chases = {
      "Apex Roofing": 0, "Crown Roof Systems": 1, "PrimeBuild": 1,
      "Skyline Exteriors": 1, "Halewood Roofing": 1,
    };
    for (const f of spec) {
      await ctx.db.insert("invitations", {
        jobId,
        firmId: ids[f.name],
        status: status[f.name],
        sentAt: now - 8 * DAY,
        chaseCount: chases[f.name],
        lastChasedAt: chases[f.name] ? now - 5 * DAY : undefined,
      });
    }

    // the quotes themselves
    const q = (name, total, lineItems, inclusions, exclusions, scopeTags, needsReview) =>
      ctx.runMutation(components.quoteEngine.quotes.record, {
        jobKey: String(jobId),
        partyKey: String(ids[name]),
        partyName: name,
        total,
        lineItems,
        inclusions,
        exclusions,
        scopeTags,
        needsReview: !!needsReview,
      });

    await q("Apex Roofing", 14200,
      [
        { label: "Tear-off and disposal", amount: 2400 },
        { label: "Asphalt shingle, supply", amount: 6100 },
        { label: "Labour", amount: 4500 },
        { label: "Delivery and skip hire", amount: 1200 },
      ],
      ["Removal and disposal", "Delivery", "Skip hire", "Sales tax", "Warranty"],
      ["Gutter replacement"],
      ["asphalt-shingle"], false);

    await q("Crown Roof Systems", 11900,
      [
        { label: "Asphalt shingle, supply and fit", amount: 10700 },
        { label: "Labour", amount: 1200 },
      ],
      ["Labour"],
      ["Removal and disposal", "Delivery", "Skip hire", "Sales tax", "Gutter replacement"],
      ["asphalt-shingle"], false);

    await q("PrimeBuild", 13450,
      [{ label: "Complete roof replacement", amount: 13450, note: "Lump sum, no breakdown given" }],
      ["Removal and disposal", "Delivery", "Sales tax"],
      ["Skip hire", "Gutter replacement"],
      ["asphalt-shingle"], true);

    await q("Skyline Exteriors", 15800,
      [
        { label: "Tear-off and disposal", amount: 2600 },
        { label: "Natural slate, supply", amount: 7400 },
        { label: "Labour, flashing and ridge", amount: 4600 },
        { label: "Delivery and crane hire", amount: 1200 },
      ],
      ["Removal and disposal", "Delivery", "Crane hire", "Sales tax", "Temporary protection", "Warranty"],
      ["Night work", "Gutter replacement"],
      ["asphalt-shingle", "slate"], false);

    return { project: "Roof replacement", companies: spec.length, replies: 5 };
  },
});
'''
open(p, "w").write(s)
print("showcase written")
PY

echo ""
echo "Run it on whichever deployment you're demoing:"
echo "  npx convex dev --once && npx convex run demo:showcase"
echo "  npx convex run --prod demo:showcase"
