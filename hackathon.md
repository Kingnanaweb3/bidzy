# Bidzy

**An agent that chases contractor quotes over email, reads whatever comes back, and works out which price is actually cheapest.**

- **Live app:** https://hushed-seahorse-768.convex.site
- **Repo:** https://github.com/Kingnanaweb3/bidzy
- **Demo video:** _(pending)_
- **Build post:** _(pending)_

Built solo, in eight days, for the Convex All Gas Hackathon.

---

## The problem

You need your roof replaced. So you email six roofing companies for a price.

Four things then go wrong, and all four cost you money.

**Most of them don't reply.** You chase by phone, or you give up and go with whoever answered.

**The prices aren't comparable.** One firm writes a tidy itemised quote. One sends a PDF. One writes "call it fourteen two all in, you sort the skip."

**The cheapest price is usually not the cheapest job.** Crown quotes $11,900. Apex quotes $14,200. Crown looks like the obvious pick until you notice Crown excludes removal and disposal, delivery, skip hire and sales tax — about $4,900 of work you'll be paying someone else to do. Crown's real cost is $16,800. Apex was cheaper the whole time.

**You change your mind, and nobody tells you which prices died.** You decide on slate instead of asphalt. Every quote priced against asphalt is now worthless. Nothing in your inbox says so.

## Why nobody has fixed it

Every attempt has been a marketplace: everyone signs up, everyone coordinates in one place.

That fails on the supply side. The roofing company is four people and a van. They are not creating an account for one job they might not win. They have a phone and an email address, and that is the entire digital surface of the business.

**Bidzy only requires one side to adopt anything.** You use it. The contractor receives ordinary email and replies with ordinary email, exactly as they do today, and may never know software was involved.

Email is not a fallback here. It is the only wire between two parties who share no software.

## What it does

Each job gets its own real inbox — `bidzy-roofing-8egxzd@agentmail.to`. Bidzy emails contractors from it, receives their replies there, and keeps working the job until there's an answer.

**It chases on its own.** A cron runs every morning whether or not anyone is watching. No reply after three days → a follow-up. Still nothing after four more → one more. Then it stops emailing and writes *"hasn't answered after 2 follow-ups, worth a phone call or dropping them"*, because a third email isn't going to work and a person should decide.

**It reads what comes back, however it arrives.** A PDF goes through Firecrawl with a schema and comes back as a total, line items, inclusions and exclusions — OCR included, because contractors photograph things. A plain email goes through an LLM that understands "fourteen two" is $14,200 and "you sort the skip" means skip hire is excluded. If it can't find a price it trusts, it says so rather than guessing, because a wrong number on a board about honest pricing is worse than no number.

**It works out the real cost.** This is the part that matters. Each quote's exclusions are priced using what the *other* contractors charged for the same item. Crown's $11,900 becomes $16,800. The board shows quoted price, missing work, and real cost as three rows, so the arithmetic is visible rather than asserted.

**It knows which prices your decision killed.** Every quote records what it depends on. Change the material to slate and only the asphalt quotes go stale — the one contractor who also priced slate survives, the board re-ranks, and the affected firms are emailed to ask whether their number still holds.

## What was interesting to build

### The job has to outlive the run

AgentMail published a piece four days before this deadline making exactly the argument this product is built on: *the work continues after the agent stops*, and losing responsibility for the unfinished job is the failure. An agent asks for a quote on Monday, the run ends, the reply arrives Thursday, and nothing connects it to the unfinished job.

So the job here is state, not a transcript. An invitation is a row with a stable id, a status, a chase count and a last-chased timestamp — "waiting on Crown since Tuesday" is something the application can query, which is what lets a scheduled function act on it days later with no conversation in context. Inbound messages are deduplicated on message id, because recording the message is what makes the job resumable and it therefore has to happen exactly once. The chase has a hard stop and hands over to a human, because waiting forever is a polite way of abandoning something.

### Quote intelligence is its own component

The app knows **who was asked**. It should not also know **what a price means**.

`quoteEngine` is a Convex component with its own isolated tables. Nothing outside it can read or write them — the only way in is its API. It never learns what a job or a contractor is; it takes opaque string keys. It owns normalisation (one firm writes "tear-off", another writes "removal and disposal of the existing roof", and the board needs one row), the benchmark prices learned from peer quotes, comparable cost, and whether a quote is still valid.

That boundary is the reason the scope-change feature is three lines in the app: the app says *the material changed to slate*, and the component answers with which prices that kills and which survive. It also means an agent working on pricing logic never has to hold the email or project code in view.

### The comparison is the product, so it had to survive a phone

A table you scroll sideways is not a comparison — you can never see two contractors at once. Below 768px the table is replaced by one card per contractor, sorted cheapest real cost first, each carrying its own arithmetic. So a phone gives you the ranking directly rather than asking you to rebuild it by scrolling.

## Stack

**Convex** — the whole backend. Reactive queries drive every screen. `changeScope` is one transactional mutation that bumps the revision, writes the change, invalidates only the dependent quotes and emits the events — all of it lands or none does, which matters when the output is a number someone will spend money against. It's idempotent, so publishing twice is a no-op. An HTTP action receives the AgentMail webhook at the deployment's own `.convex.site` domain, so there's no tunnel in the loop. A cron drives the chase. `quoteEngine` and `staticHosting` are both installed components, and the app is served from the same deployment that runs it.

**AgentMail** — one real inbox per job, created from the API, with two-way threading and webhooks on inbound mail. Invitations, follow-ups and reprice requests all go out from it. The contractor sees an email from a person about a roof.

**Firecrawl** — `/v2/scrape` with a JSON schema and the PDF parser set to auto, so a quote document returns structured fields rather than text to regex. The extracted material feeds the scope tags, which is what lets a slate quote survive a switch to slate. Firecrawl decides what a document covers; the component decides whether that's still valid.

**Groq** — reads plain email bodies into the same shape Firecrawl returns for PDFs, with the regex parser kept underneath as a floor so a missing key can't break the loop.

## Honest limits

- **Licence status is seeded, not checked.** Contractor licences are public record and the lookup is a real feature — it isn't built. The red badge is demo data and shouldn't be read as verification.
- **The AgentMail webhook signature isn't verified.** The secret is issued and stored; checking it is a small change that didn't get made. Anyone who found the endpoint URL could post to it.
- **There's no auth.** One project, one implied user.
- **Benchmark pricing needs peers.** With one quote on the board there's nothing to price exclusions against, so "real cost" equals the quoted price until a second contractor replies.
- **The LLM reader is not always right**, which is why an unconfident parse is flagged for a human rather than written to the board as fact.
- **Contractor discovery isn't built.** Firms are entered rather than found.

## What I'd do next

Verify licences and insurance against state registers with Firecrawl `/search`. Watch material prices with `/monitor`, since a quote held for 30 days is exposed to them. Find contractors rather than requiring them. And multi-job projects, because a real renovation is fifteen of these at once and the component boundary already supports it.

## Why it matters past the demo

Construction is around 13% of global GDP and the least digitised major industry there is. But the interesting part isn't roofing.

The counterparty will never install your software. That isn't a construction problem — it's most of the economy. Every previous answer was to make them adopt something. An agent with an email address is the first thing that can sit entirely on one side and work with the world as it already is.
