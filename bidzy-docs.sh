#!/bin/bash
# Writes hackathon.md and README.md into the project root.
set -e
[ -d convex ] || { echo "Run from the bidzy project root."; exit 1; }

cat > hackathon.md << 'EOF'
# Bidzy

**An agent that chases construction price quotes over email, reads them, and lines them up side by side.**

- **Live app:** _(pending deploy)_
- **Demo video:** _(pending)_
- **Repo:** https://github.com/Kingnanaweb3/bidzy
- **Build post:** _(pending)_

---

## The problem

When a construction company bids on a building, they don't build it themselves. They hire specialists — one firm for concrete, one for windows, one for wiring. About twenty different jobs.

Before they can promise the customer a price, they need to know what each of those jobs will cost. So they email specialist firms asking for a price. They need three prices per job to compare, which is sixty prices, which means emailing around two hundred firms because most never reply.

Then it gets worse:

- **Everything arrives at once.** Most prices come in during the final two days.
- **No two look the same.** One is a clean PDF, one is a photo of a handwritten page. One includes tax, one doesn't.
- **The real cost is hidden at the bottom.** Every quote lists what the firm is *not* doing. Firm A quotes $180,400 and does the fireproofing. Firm B quotes $168,900 and doesn't. B looks cheaper and is actually more expensive.
- **The plans keep changing mid-way.** The architect updates the design. Firms who already priced are now pricing the old drawings, and nobody notices until after the bid is submitted.
- **Nobody checks credentials.** Licences expire, and they're published free on government websites. Checking two hundred firms by hand doesn't happen, so it never happens.

The construction company submits one number. It's binding. If they missed something, they absorb the loss.

## Why nobody has fixed it

Every previous attempt has been a website where everyone logs in and coordinates.

It fails for one reason: **the specialist firms will never log in.** The drywall firm is nine people and a truck. He isn't creating an account for one job he might not win. He has a phone and an email address, and that's the whole digital surface of his business.

Any tool needing both sides to sign up is dead before it launches.

**Bidzy only needs one side.** The construction company uses it. The specialist gets a normal email and replies with a normal email, exactly as they do now.

Email isn't a fallback here. It's the only wire between two firms that share no software.

## What's built

**The board.** Four firms across the top, their prices, and underneath a grid of everything each one refuses to do. The cheapest number on the board excludes fireproofing, crane hire and sales tax — the grid makes that visible at a glance instead of buried in a paragraph.

**Selective repricing.** Each quote is tagged with the parts of the design it depends on. When the architect publishes a change, only the quotes that actually depend on the changed part go stale. The rest stay live, the board re-ranks the survivors, and a banner states the new best valid price and what it moved from. Affected firms are asked to confirm whether their price still holds.

This is the core insight of the product: a design change is not a blanket alarm, it's a targeted one. Flagging everything is the same as flagging nothing.

**Live throughout.** Everything on screen is a Convex reactive query. Publishing a design change updates the board, the banner and the activity feed with no refresh and no polling.

## Stack

**Convex** — the whole backend. Reactive queries drive the board and the activity feed. `publishAddendum` is a single transactional mutation that bumps the project revision, writes the addendum, stales only the dependent quotes, and emits three events — either all of it lands or none does, which matters when the output is a binding price. The mutation is idempotent: publishing twice is a no-op rather than a double-count.

*(Next: lifting each job into its own Convex component, so an agent working one trade can hold it entirely in view and cannot reach across into another trade's quotes.)*

**Firecrawl** — _(in progress)_ `/parse` on incoming quote PDFs, `/search` against government licence registries, `/monitor` on plan pages so a design change is detected rather than simulated. In research, a change on the web is interesting. In construction, a change is liability.

**AgentMail** — _(in progress)_ one real two-way inbox per job. No login, no portal, nothing for the other side to adopt.

## Status

Honest account as of 15 Sep:

- Working: the board, the exclusions grid, selective staleness, re-ranking, the activity feed, reset-and-replay for the demo.
- Seeded: quote data is realistic but hand-authored. PDF parsing not yet wired.
- Simulated: the design change is published by a button, not yet detected by a monitor.
- Not started: outbound email, licence checks.

## Why this matters past the demo

Construction is roughly 13% of global GDP and the least digitised major industry on earth. The pricing stage decides whether a project makes or loses money, and almost no software has landed there — not because the problem is boring, but because the other party was unreachable.

The counterparty will never install your software. That isn't a construction problem. It's most of the economy.
EOF

cat > README.md << 'EOF'
# Bidzy

**An agent that chases construction price quotes over email, reads them, and lines them up side by side.**

[Build log](./hackathon.md)

> A construction company emails 200 specialist firms to collect 60 prices, and most arrive in the final two days as inconsistent PDFs with the real cost hidden at the bottom. Those firms will never log into a portal — email is the only wire between them. So we put an agent on it.

Built for the Convex All Gas Hackathon.

---

## What it does

Each job on a building project gets its own agent and its own inbox. The agent emails specialist firms asking for a price, chases the ones who go quiet, reads the quotes as they land, and lines them up on a live board with everything each firm refuses to do pulled out where you can see it.

When the architect changes the design, only the quotes that depend on the changed part go stale. The board re-ranks what's left and says what the new best valid price is.

## Running it

```bash
npm install
npx convex dev          # leave running
npx convex run seed:demo
npm run dev
```

## Try the demo

Open the app, then click **Publish design change**. Three quotes strike through as priced against the old drawings; one firm priced the current drawings and survives; the board re-ranks and tells you the best valid price moved from $168,900 to $174,600.

**Reset demo** puts it back.

## Architecture

```
convex/
  schema.ts       projects, jobs, firms, invitations, quotes, addenda, events
  projects.ts     publishAddendum - transactional, selective, idempotent
  jobs.ts         board - one reactive query backing the whole screen
  quotes.ts       record / confirm
  seed.ts         demo data
src/components/
  Board.tsx       the comparison board
  Header.tsx      design-change control
  Feed.tsx        live activity
```

## Stack

- **Convex** — database, reactive queries, transactional mutations, hosting
- **Firecrawl** — quote PDF parsing, licence lookups, plan monitoring _(in progress)_
- **AgentMail** — one inbox per job _(in progress)_

## Status

See [hackathon.md](./hackathon.md) for an honest account of what's built and what isn't.
EOF

echo "docs written"
