# Recyv

Get paid with a link. Crypto payment links settling on Robinhood Chain.

```
Create → Share → Pay → Receive
```

## Run it

```bash
npm install
cp .env.example .env.local   # fill CHAIN_ID and RPC_URL
npm run dev
```

Two values in `.env.local` are the only things standing between this and a
working app: `NEXT_PUBLIC_CHAIN_ID` and `NEXT_PUBLIC_RPC_URL`. Everything else
has a default.

## What's here

| Path | Does |
|---|---|
| `app/page.tsx` | Create a request, get a link + QR |
| `app/r/[id]/page.tsx` | Public payment page |
| `app/dashboard/page.tsx` | Payments received, read from Transfer logs |
| `lib/token-config.ts` | **The fast token swap** |
| `lib/link.ts` | Request ⇄ link encoding |
| `lib/chain.ts` | Chain + ERC-20 constants |

Payment requests are encoded into the link itself, so there's no database to
stand up before the demo. Move to short ids (`recyv.xyz/r/8Kx29A`) with a KV
store when you want branded links.

---

## Launch-day runbook: swapping the token CA

The address is **never baked into the build**. The app fetches
`NEXT_PUBLIC_TOKEN_CONFIG_URL` every 5 seconds with `cache: no-store`, so
changing it propagates to every open browser without a rebuild, a redeploy, or
a reload.

### Before launch

Host the config somewhere you can edit in one action — Vercel Edge Config, a
gist, an S3 object. Set `NEXT_PUBLIC_TOKEN_CONFIG_URL` to it and deploy. Serve
it with `Cache-Control: no-store` and CORS open, or the poll will read a stale
copy from a CDN.

```json
{ "address": "0x0000…0000", "symbol": "RECYV", "decimals": 18, "live": false }
```

While `live` is false or the address is the zero address, the Pay button stays
disabled and the page says so. Nothing silently sends funds to a placeholder.

### At launch — the ten seconds

1. Deploy the token, copy the CA.
2. Paste it into the config, set `"live": true`. Save.
3. Done. Every open tab flips within 5 seconds.

### If the config host is slow or down

Two overrides that need no infrastructure at all:

- **URL:** append `?token=0xABC…` to any Recyv page — takes effect on load,
  that tab only. Good for the demo screen.
- **Console:** `recyvSetToken("0xABC…")` — sticks in `localStorage` for that
  browser.

Both beat the hosted config, so you can go live from the podium even if the
config edit hasn't landed.

### Why the app calls `symbol()` and `decimals()` first

A one-character typo in a pasted CA is an address that still looks valid.
Before enabling payments the app reads the contract; if it doesn't answer like
an ERC-20 on this chain, payments stay paused and the page says why. It costs
one RPC round-trip and it's the difference between a paused demo and payments
sent somewhere unrecoverable.

**One thing worth locking down before mainnet, since you're going live for
real:** whoever can write to that config URL controls where every payment
button points. Put it behind auth you control — not a public gist you can also
edit, and not a repo with the hackathon team's write access. This is the single
highest-value target in the whole app, and it's outside anything a contract
audit would look at.

---

## Not done yet (deliberately out of MVP scope)

- Short link ids (needs a KV store)
- Invoices, receipts, recurring payments — the V2/V3 roadmap
- Chain switching if the wallet is on the wrong network
- Rate limiting on the config poll for large traffic

## Not built, and shouldn't be

The token stays separate from the payment flow. Nobody should need to hold
RECYV to pay a freelancer 50 USDC — that's the thing that makes this read as a
real payment product rather than a token wrapper.
