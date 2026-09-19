#!/bin/bash
# Detail pass: mono for machine data, footer metadata rows, dot headers,
# and one primary action on the winning quote.
set -e
[ -d convex/quoteEngine ] || { echo "Run from the bidzy project root."; exit 1; }

# ---------- mono, and a metadata row primitive ----------
python3 - << 'PY'
p = "src/index.css"
s = open(p).read()
if "--mono" not in s:
    s = s.replace(
'''.num {
  font-family: Inter, ui-sans-serif, system-ui, sans-serif;
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.015em;
}''',
'''.num {
  font-family: Inter, ui-sans-serif, system-ui, sans-serif;
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.015em;
}

/* Machine data reads as machine data: addresses, ids, sources, file
   names. Never a human-written sentence. */
.mono {
  font-family: "Geist Mono", ui-monospace, "SF Mono", monospace;
  font-size: 0.92em;
  letter-spacing: 0;
}''')
    open(p, "w").write(s)
    print("mono class in")
PY

python3 - << 'PY'
p = "index.html"
s = open(p).read()
if "Geist+Mono" not in s:
    s = s.replace(
      'family=Inter:wght@500;600;700;800&display=swap',
      'family=Inter:wght@500;600;700;800&family=Geist+Mono:wght@400;500&display=swap')
    open(p, "w").write(s)
    print("Geist Mono loaded")
PY

# ---------- shared bits ----------
python3 - << 'PY'
p = "src/components/ui.tsx"
s = open(p).read()

if "export function Meta" not in s:
    s += '''

// The quiet row at the foot of a card: what is happening on the left,
// when it last moved on the right.
export function Meta({ left, right }) {
  return (
    <div className="mt-3 pt-3 border-t border-[#2A2A2A] flex items-center justify-between gap-3">
      <span className="text-[11.5px] text-[#8A8A8A] truncate">{left}</span>
      {right && (
        <span className="text-[11px] text-[#5A5A5A] shrink-0">{right}</span>
      )}
    </div>
  );
}

export function Dot({ tone = "neutral" }) {
  const tones = {
    neutral: "bg-[#5A5A5A]",
    good: "bg-[#4ADE80]",
    warn: "bg-[#FBBF24]",
    bad: "bg-[#F87171]",
    info: "bg-[#2F7FFF]",
  };
  return <span className={`h-2 w-2 rounded-full shrink-0 ${tones[tone]}`} />;
}

export function Action({ children, onClick }) {
  return (
    <button
      onClick={onClick}
      className="h-8 px-3 rounded-lg text-[12.5px] font-medium
        bg-[#2E2E2E] text-[#EDEDED] border border-[#3A3A3A]
        hover:bg-[#383838] transition"
    >
      {children}
    </button>
  );
}

export const ago = (t) => {
  const m = Math.round((Date.now() - t) / 60000);
  if (m < 1) return "just now";
  if (m < 60) return `${m}m ago`;
  const h = Math.round(m / 60);
  if (h < 24) return `${h}h ago`;
  return `${Math.round(h / 24)}d ago`;
};
'''
    open(p, "w").write(s)
    print("Meta, Dot, Action, ago added")
PY

# ---------- stat cards get a dot and a count ----------
python3 - << 'PY'
p = "src/components/Stats.tsx"
s = open(p).read()
s = s.replace(
  'import { Card, Chip, IconBox, I, money } from "./ui";',
  'import { Card, Chip, Dot, IconBox, I, money } from "./ui";'
)
s = s.replace(
'''      <div className="h-9 flex items-center gap-3 mb-5">
        <IconBox>{icon}</IconBox>
        <span className="text-[12.5px] sm:text-[13.5px] font-semibold">{label}</span>
      </div>''',
'''      <div className="h-9 flex items-center gap-3 mb-5">
        <IconBox>{icon}</IconBox>
        <span className="text-[12.5px] sm:text-[13.5px] font-semibold">{label}</span>
        {tone && <span className="ml-auto"><Dot tone={tone} /></span>}
      </div>''')
s = s.replace("function Stat({ icon, label, value, foot, chip, accent, dim }) {",
              "function Stat({ icon, label, value, foot, chip, accent, dim, tone }) {")
s = s.replace('        foot={d.lowestParty ?? "no valid price yet"}\n        accent',
              '        foot={d.lowestParty ?? "no valid price yet"}\n        tone="good"\n        accent')
s = s.replace('        dim\n        foot={d.headlineParty ?? "waiting on prices"}',
              '        dim\n        tone={d.headlineMisleads ? "warn" : "neutral"}\n        foot={d.headlineParty ?? "waiting on prices"}')
s = s.replace('        icon={I.mail}\n        label="Replies"',
              '        icon={I.mail}\n        tone={d.staleCount > 0 ? "warn" : "info"}\n        label="Replies"')
open(p, "w").write(s)
print("stat cards carry a status dot")
PY

# ---------- board: mono sources, footer metadata, choose action ----------
python3 - << 'PY'
p = "src/components/Board.tsx"
s = open(p).read()

s = s.replace(
  'import { Card, CardHead, Chip, I, money } from "./ui";',
  'import { Card, CardHead, Chip, Action, Meta, ago, I, money } from "./ui";'
)

# the real-cost cell gains a footer row and, for the winner, an action
s = s.replace(
'''                      <span className="block text-[11px] mt-1.5 leading-4 min-h-[16px]">
                        {best && (
                          <span className="text-[#4ADE80]">
                            cheapest once compared fairly
                          </span>
                        )}
                        {r.quote?.stale && (
                          <span className="text-[#FBBF24]">priced the old job</span>
                        )}
                        {r.quote?.needsReview && !r.quote?.stale && !best && (
                          <span className="text-[#60A5FA]">worth checking</span>
                        )}
                      </span>''',
'''                      <span className="block text-[11px] mt-1.5 leading-4 min-h-[16px]">
                        {best && (
                          <span className="text-[#4ADE80]">
                            cheapest once compared fairly
                          </span>
                        )}
                        {r.quote?.stale && (
                          <span className="text-[#FBBF24]">priced the old job</span>
                        )}
                        {r.quote?.needsReview && !r.quote?.stale && !best && (
                          <span className="text-[#60A5FA]">worth checking</span>
                        )}
                      </span>

                      {r.quote && (
                        <Meta
                          left={
                            r.quote.exclusions.length
                              ? `${r.quote.exclusions.length} not covered`
                              : "covers everything"
                          }
                          right={ago(r.quote.receivedAt)}
                        />
                      )}

                      {best && (
                        <div className="mt-3">
                          <Action>Choose this quote</Action>
                        </div>
                      )}''')

# the licence link shows its source in mono
s = s.replace(
'''                        <Chip tone="good">licence checked</Chip>''',
'''                        <Chip tone="good">licence checked</Chip>''')
open(p, "w").write(s)
print("board footers and action in")
PY

# ---------- inbox: addresses and subjects in mono ----------
python3 - << 'PY'
p = "src/pages/InboxPage.tsx"
s = open(p).read()
s = s.replace(
  'import { Card, CardHead, Chip, Ghost, Empty, I, when } from "../components/ui";',
  'import { Card, CardHead, Chip, Ghost, Empty, Meta, I, when, ago } from "../components/ui";'
)
s = s.replace(
  'title={job.inboxAddress ?? "No inbox yet"}',
  'title={<span className="mono">{job.inboxAddress ?? "No inbox yet"}</span>}'
)
s = s.replace(
  '''                    <p className="text-[12.5px] text-[#A1A1A1] truncate leading-5">
                      {m.subject ?? "(no subject)"}
                    </p>''',
  '''                    <p className="text-[12.5px] text-[#A1A1A1] truncate leading-5">
                      {m.subject ?? "(no subject)"}
                    </p>
                    <p className="mono text-[11px] text-[#5A5A5A] truncate mt-1">
                      {m.direction === "in" ? m.fromAddress : m.toAddress}
                    </p>''')
s = s.replace(
  "We don't recognise {message.fromAddress}. Their price won't be",
  "We don't recognise <span className=\"mono\">{message.fromAddress}</span>. Their price won't be")
open(p, "w").write(s)
print("inbox uses mono for addresses")
PY

# ---------- documents: line items get a metadata footer ----------
python3 - << 'PY'
p = "src/pages/DocsPage.tsx"
s = open(p).read()
s = s.replace(
  'import { Card, CardHead, Chip, Primary, Empty, I, money } from "../components/ui";',
  'import { Card, CardHead, Chip, Primary, Empty, Meta, ago, I, money } from "../components/ui";'
)
s = s.replace(
'''                {r.quote.exclusions.length > 0 && (
                  <p className="text-[12px] text-[#F87171] mt-4 leading-5">
                    Not covered: {r.quote.exclusions.join(", ")}
                  </p>
                )}''',
'''                {r.quote.exclusions.length > 0 && (
                  <p className="text-[12px] text-[#F87171] mt-4 leading-5">
                    Not covered: {r.quote.exclusions.join(", ")}
                  </p>
                )}
                <Meta
                  left={
                    <>
                      {r.quote.lineItems.length} line item
                      {r.quote.lineItems.length === 1 ? "" : "s"} read
                      {r.quote.sourceUrl ? " from a document" : " from an email"}
                    </>
                  }
                  right={ago(r.quote.receivedAt)}
                />''')
open(p, "w").write(s)
print("documents footer in")
PY

# ---------- mobile cards match ----------
python3 - << 'PY'
p = "src/components/BoardMobile.tsx"
s = open(p).read()
s = s.replace('import { Chip, money } from "./ui";',
              'import { Chip, Meta, ago, money } from "./ui";')
s = s.replace(
'''                {q.exclusions.length > 0 && (
                  <details className="mt-3 group">''',
'''                <Meta
                  left={
                    q.exclusions.length
                      ? `${q.exclusions.length} not covered`
                      : "covers everything"
                  }
                  right={ago(q.receivedAt)}
                />

                {q.exclusions.length > 0 && (
                  <details className="mt-3 group">''')
open(p, "w").write(s)
print("mobile cards match")
PY

echo ""
echo "Then: npm run dev"
