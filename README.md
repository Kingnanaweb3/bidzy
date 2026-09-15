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
