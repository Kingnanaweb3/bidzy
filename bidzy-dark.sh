#!/bin/bash
# Bidzy dark dashboard. Same Convex bindings, new skin.
set -e
[ -d convex/quoteEngine ] || { echo "Run from the bidzy project root."; exit 1; }

cat > index.html << 'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Bidzy — what the quote actually costs</title>
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap" rel="stylesheet" />
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

cat > src/index.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root { color-scheme: dark; }

html, body { background: #171717; }
body {
  margin: 0;
  color: #EDEDED;
  font-family: "Plus Jakarta Sans", ui-sans-serif, system-ui, sans-serif;
  -webkit-font-smoothing: antialiased;
}

.num { font-variant-numeric: tabular-nums; }

::selection { background: #1E3A5F; }
*:focus-visible { outline: 2px solid #3B82F6; outline-offset: 2px; }
input, select, button { font-family: inherit; }
input::placeholder { color: #5A5A5A; }

::-webkit-scrollbar { height: 8px; width: 8px; }
::-webkit-scrollbar-thumb { background: #333; border-radius: 4px; }
::-webkit-scrollbar-track { background: transparent; }

@media (prefers-reduced-motion: reduce) {
  * { transition: none !important; animation: none !important; }
}
EOF

cat > src/components/ui.tsx << 'EOF'
export function Card({ children, className = "" }) {
  return (
    <div className={`bg-[#1F1F1F] border border-[#2E2E2E] rounded-2xl ${className}`}>
      {children}
    </div>
  );
}

export function Chip({ children, tone = "neutral" }) {
  const tones = {
    neutral: "bg-[#2A2A2A] text-[#A1A1A1]",
    good: "bg-[#0F2C1F] text-[#4ADE80]",
    warn: "bg-[#2E2410] text-[#FBBF24]",
    bad: "bg-[#2E1515] text-[#F87171]",
    info: "bg-[#12243D] text-[#60A5FA]",
  };
  return (
    <span className={`text-[11px] font-medium px-2 py-1 rounded-md ${tones[tone]}`}>
      {children}
    </span>
  );
}

export function IconBox({ children }) {
  return (
    <div className="h-9 w-9 rounded-xl bg-[#2A2A2A] grid place-items-center text-[#A1A1A1] shrink-0">
      {children}
    </div>
  );
}

export function Primary({ children, onClick, disabled }) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className="text-[13px] font-semibold rounded-xl px-4 py-2.5 bg-[#2F7FFF]
        text-white hover:bg-[#1F6FEF] transition
        disabled:bg-[#2A2A2A] disabled:text-[#5A5A5A]"
    >
      {children}
    </button>
  );
}

export function Ghost({ children, onClick, disabled }) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className="text-[13px] font-medium rounded-xl px-4 py-2.5 bg-[#252525]
        text-[#C9C9C9] border border-[#2E2E2E] hover:bg-[#2C2C2C] hover:text-white
        transition disabled:opacity-40"
    >
      {children}
    </button>
  );
}

export const I = {
  home: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><path d="M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/></svg>,
  mail: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/></svg>,
  doc: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><path d="M14 3v5h5"/><path d="M14 3H6a1 1 0 0 0-1 1v16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V8z"/></svg>,
  scale: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><path d="M12 3v18M5 7h14M7 7l-3 7h6zM17 7l-3 7h6z"/></svg>,
  clock: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>,
  alert: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><path d="M12 9v4M12 17h.01"/><circle cx="12" cy="12" r="9"/></svg>,
  wallet: <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><rect x="3" y="6" width="18" height="13" rx="2"/><path d="M3 10h18M17 14h.01"/></svg>,
  search: <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>,
};
EOF

cat > src/App.tsx << 'EOF'
import { useQuery } from "convex/react";
import { api } from "../convex/_generated/api";
import Board from "./components/Board";
import Feed from "./components/Feed";
import Header from "./components/Header";
import Inbox from "./components/Inbox";
import ReadDoc from "./components/ReadDoc";
import Sidebar from "./components/Sidebar";
import Stats from "./components/Stats";

export default function App() {
  const projects = useQuery(api.projects.list);
  const project = projects?.[0];
  const jobs = useQuery(
    api.jobs.listByProject,
    project ? { projectId: project._id } : "skip"
  );
  const job = jobs?.[0];

  if (projects === undefined) return <Splash text="Loading" />;
  if (!project) return <Splash text="No project yet. Run the seed to start one." />;

  return (
    <div className="min-h-screen bg-[#171717] lg:p-3">
      <div className="lg:flex lg:gap-3">
        <Sidebar project={project} job={job} />
        <div className="flex-1 min-w-0 bg-[#1A1A1A] lg:rounded-3xl lg:border lg:border-[#2A2A2A]">
          <Header project={project} />
          <main className="px-5 sm:px-7 pb-10">
            {job ? (
              <>
                <Stats jobId={job._id} project={project} />
                <div className="grid grid-cols-1 2xl:grid-cols-[minmax(0,1fr)_330px] gap-5 mt-5">
                  <div className="min-w-0 space-y-5">
                    <Board jobId={job._id} />
                    <Inbox job={job} jobId={job._id} />
                    <Docs jobId={job._id} />
                  </div>
                  <Feed projectId={project._id} />
                </div>
              </>
            ) : (
              <Splash text="No job on this project yet." />
            )}
          </main>
        </div>
      </div>
    </div>
  );
}

function Docs({ jobId }) {
  const data = useQuery(api.jobs.board, { jobId });
  if (!data) return null;
  return <ReadDoc jobId={jobId} rows={data.rows} />;
}

function Splash({ text }) {
  return (
    <div className="min-h-screen grid place-items-center text-[#5A5A5A] text-sm">
      {text}
    </div>
  );
}
EOF

cat > src/components/Sidebar.tsx << 'EOF'
import { I } from "./ui";

export default function Sidebar({ project, job }) {
  return (
    <aside className="hidden lg:flex w-[228px] shrink-0 flex-col py-6 px-4">
      <div className="flex items-center gap-2.5 px-2 mb-8">
        <div className="h-9 w-9 rounded-xl bg-[#2F7FFF] grid place-items-center">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.2">
            <path d="M4 18 12 5l8 13" /><path d="M8 18h8" />
          </svg>
        </div>
        <span className="text-[17px] font-bold tracking-tight">Bidzy</span>
      </div>

      <Group label="This project" />
      <Item icon={I.scale} active>Compare prices</Item>
      <Item icon={I.mail}>Inbox</Item>
      <Item icon={I.doc}>Documents</Item>
      <Item icon={I.clock}>Activity</Item>

      <Group label="General" />
      <Item icon={I.home}>Projects</Item>
      <Item icon={I.wallet}>Budget</Item>

      <div className="mt-auto">
        <div className="rounded-2xl bg-[#1F1F1F] border border-[#2E2E2E] p-4">
          <p className="text-[12px] text-[#A1A1A1] leading-relaxed">
            Companies reply to
          </p>
          <p className="text-[12px] text-[#EDEDED] break-all mt-1">
            {job?.inboxAddress ?? "no inbox yet"}
          </p>
          <p className="text-[11px] text-[#5A5A5A] mt-2 leading-relaxed">
            They never sign in. It's just email.
          </p>
        </div>
      </div>
    </aside>
  );
}

function Group({ label }) {
  return (
    <p className="text-[10px] font-semibold tracking-[0.12em] uppercase text-[#5A5A5A] px-2 mt-6 mb-2">
      {label}
    </p>
  );
}

function Item({ icon, children, active }) {
  return (
    <div
      className={`flex items-center gap-3 px-3 py-2.5 rounded-xl text-[13.5px] mb-0.5 ${
        active
          ? "bg-[#242424] text-white font-medium"
          : "text-[#A1A1A1] hover:text-[#EDEDED]"
      }`}
    >
      <span className={active ? "text-[#2F7FFF]" : ""}>{icon}</span>
      {children}
    </div>
  );
}
EOF

cat > src/components/Header.tsx << 'EOF'
import { useMutation, useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { useState } from "react";
import { I, Primary, Ghost } from "./ui";

export default function Header({ project }) {
  const change = useMutation(api.projects.changeScope);
  const reset = useMutation(api.projects.resetStale);
  const addenda = useQuery(api.projects.addenda, { projectId: project._id });
  const [busy, setBusy] = useState(false);
  const changed = (addenda?.length ?? 0) > 0;

  return (
    <div className="px-5 sm:px-7 pt-6 pb-5">
      <div className="flex items-center gap-4 mb-7">
        <div className="flex items-center gap-2.5 bg-[#1F1F1F] border border-[#2E2E2E] rounded-xl px-3.5 py-2.5 w-full max-w-[380px] text-[#5A5A5A]">
          {I.search}
          <span className="text-[13px]">Search companies, prices, email</span>
        </div>
        <div className="ml-auto flex items-center gap-2.5">
          <div className="hidden sm:flex items-center gap-2 bg-[#1F1F1F] border border-[#2E2E2E] rounded-xl px-3.5 py-2.5 text-[12.5px] text-[#A1A1A1]">
            {I.home}
            {project.scopeNote}
          </div>
          <div className="h-9 w-9 rounded-full bg-[#2A2A2A] grid place-items-center text-[12px] font-semibold text-[#A1A1A1]">
            H
          </div>
        </div>
      </div>

      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-[26px] font-bold tracking-tight">
            {project.name}
          </h1>
          <p className="text-[13.5px] text-[#A1A1A1] mt-1">
            {project.client} — prices arrive by email and are compared here like
            for like.
          </p>
        </div>
        <div className="flex gap-2.5">
          {changed && (
            <Ghost
              busy={busy}
              onClick={async () => {
                setBusy(true);
                await reset({ projectId: project._id });
                setBusy(false);
              }}
            >
              Undo
            </Ghost>
          )}
          <Primary
            disabled={busy || changed}
            onClick={async () => {
              setBusy(true);
              await change({ projectId: project._id });
              setBusy(false);
            }}
          >
            {changed ? "Changed to slate" : "Change to slate instead"}
          </Primary>
        </div>
      </div>
    </div>
  );
}
EOF

cat > src/components/Stats.tsx << 'EOF'
import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, Chip, IconBox, I } from "./ui";

const money = (n) =>
  n == null ? "—" : "$" + n.toLocaleString(undefined, { maximumFractionDigits: 0 });

export default function Stats({ jobId }) {
  const d = useQuery(api.jobs.board, { jobId });
  if (!d) return null;

  const gap =
    d.lowest != null && d.headlineLowest != null
      ? d.lowest - d.headlineLowest
      : null;

  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
      <Card className="p-5">
        <div className="flex items-center gap-3 mb-4">
          <IconBox>{I.scale}</IconBox>
          <span className="text-[13.5px] font-semibold">Best real cost</span>
        </div>
        <p className="num text-[30px] font-bold tracking-tight">
          {money(d.lowest)}
        </p>
        <p className="text-[12.5px] text-[#A1A1A1] mt-2">
          {d.lowestParty ?? "no valid price yet"}
        </p>
      </Card>

      <Card className="p-5">
        <div className="flex items-center gap-3 mb-4">
          <IconBox>{I.alert}</IconBox>
          <span className="text-[13.5px] font-semibold">Cheapest on paper</span>
        </div>
        <p className="num text-[30px] font-bold tracking-tight text-[#A1A1A1]">
          {money(d.headlineLowest)}
        </p>
        <div className="flex items-center gap-2 mt-2">
          {d.headlineMisleads ? (
            <>
              <Chip tone="warn">
                really {gap > 0 ? "+" : ""}
                {money(Math.abs(gap))} more
              </Chip>
              <span className="text-[12.5px] text-[#A1A1A1]">
                {d.headlineParty}
              </span>
            </>
          ) : (
            <span className="text-[12.5px] text-[#A1A1A1]">
              {d.headlineParty ?? "waiting on prices"}
            </span>
          )}
        </div>
      </Card>

      <Card className="p-5">
        <div className="flex items-center gap-3 mb-4">
          <IconBox>{I.mail}</IconBox>
          <span className="text-[13.5px] font-semibold">Replies</span>
        </div>
        <p className="num text-[30px] font-bold tracking-tight">
          {d.quotedCount}
          <span className="text-[#5A5A5A]">/{d.invitedCount}</span>
        </p>
        <div className="flex items-center gap-2 mt-2">
          {d.staleCount > 0 ? (
            <Chip tone="warn">{d.staleCount} need repricing</Chip>
          ) : (
            <Chip tone="good">all current</Chip>
          )}
        </div>
      </Card>
    </div>
  );
}
EOF

cat > src/components/Board.tsx << 'EOF'
import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, Chip, IconBox, I } from "./ui";

const money = (n) =>
  n == null ? "—" : "$" + n.toLocaleString(undefined, { maximumFractionDigits: 0 });

export default function Board({ jobId }) {
  const d = useQuery(api.jobs.board, { jobId });
  if (!d) return <Card className="p-5 text-[13px] text-[#5A5A5A]">Loading…</Card>;

  const {
    rows, allExclusions, lowest, lowestParty,
    headlineLowest, headlineParty, headlineMisleads,
    previousBest, lowestMoved, staleCount,
  } = d;

  return (
    <Card>
      <div className="flex items-center gap-3 px-5 py-4 border-b border-[#2A2A2A]">
        <IconBox>{I.scale}</IconBox>
        <div>
          <h2 className="text-[14.5px] font-semibold">Price comparison</h2>
          <p className="text-[12px] text-[#5A5A5A] mt-0.5">
            Missing work is priced from what the others charged
          </p>
        </div>
      </div>

      {(lowestMoved || headlineMisleads) && (
        <div className="mx-5 mt-5 rounded-xl bg-[#2E2410] border border-[#443415] px-4 py-3.5">
          <p className="text-[13.5px] text-[#FBBF24] leading-relaxed">
            {lowestMoved ? (
              <>
                You changed the job, so {staleCount} price
                {staleCount === 1 ? "" : "s"} no longer{" "}
                {staleCount === 1 ? "applies" : "apply"}. {lowestParty} already
                priced this and still stands at {money(lowest)}, up from{" "}
                {money(previousBest)}.
              </>
            ) : (
              <>
                {headlineParty} looks cheapest at {money(headlineLowest)} — but
                once the work they leave out is priced in, {lowestParty} is the
                cheaper job at {money(lowest)}.
              </>
            )}
          </p>
        </div>
      )}

      <div className="overflow-x-auto p-5">
        <table className="w-full border-collapse text-[13.5px] min-w-[700px]">
          <thead>
            <tr className="text-left">
              <th className="w-[140px] pb-3 text-[12px] font-medium text-[#5A5A5A]">
                Company
              </th>
              {rows.map((r) => (
                <th key={r.firmId} className="pb-3 px-4 min-w-[168px]">
                  <div
                    className={`font-semibold ${
                      r.quote?.stale ? "text-[#5A5A5A]" : "text-[#EDEDED]"
                    }`}
                  >
                    {r.firmName}
                  </div>
                  <div className="flex flex-wrap gap-1.5 mt-2">
                    <Status row={r} />
                    {r.licenceStatus === "expired" && (
                      <Chip tone="bad">licence expired</Chip>
                    )}
                  </div>
                </th>
              ))}
            </tr>
          </thead>

          <tbody>
            <Line label="Quoted" note="what they wrote">
              {rows.map((r) => (
                <td
                  key={r.firmId}
                  className={`px-4 py-3 ${r.quote?.stale ? "opacity-40" : ""}`}
                >
                  <span className="num text-[15px] text-[#A1A1A1]">
                    {money(r.quote?.total)}
                  </span>
                </td>
              ))}
            </Line>

            <Line label="Missing work" note="priced from the others">
              {rows.map((r) => (
                <td
                  key={r.firmId}
                  className={`px-4 py-3 align-top ${
                    r.quote?.stale ? "opacity-40" : ""
                  }`}
                >
                  {r.quote ? (
                    r.quote.hidden > 0 ? (
                      <>
                        <span className="num text-[15px] text-[#FBBF24]">
                          + {money(r.quote.hidden)}
                        </span>
                        <span className="block text-[11.5px] text-[#5A5A5A] mt-1.5 leading-snug">
                          {r.quote.gaps.map((g) => g.label).join(", ")}
                        </span>
                      </>
                    ) : (
                      <span className="text-[12.5px] text-[#5A5A5A]">
                        nothing left out
                      </span>
                    )
                  ) : (
                    <span className="text-[#3A3A3A]">—</span>
                  )}
                </td>
              ))}
            </Line>

            <tr>
              <td className="pt-4 pr-4 align-top">
                <div className="text-[13.5px] font-semibold">Real cost</div>
                <div className="text-[11.5px] text-[#5A5A5A] mt-0.5">
                  like for like
                </div>
              </td>
              {rows.map((r) => {
                const best =
                  r.quote?.comparable != null &&
                  r.quote.comparable === lowest &&
                  !r.quote.stale;
                return (
                  <td
                    key={r.firmId}
                    className={`px-4 pt-4 pb-1 align-top ${
                      r.quote?.stale ? "opacity-40" : ""
                    }`}
                  >
                    <div
                      className={`rounded-xl px-3.5 py-3 border ${
                        best
                          ? "bg-[#0F2C1F] border-[#1B4A33]"
                          : "bg-[#242424] border-[#2E2E2E]"
                      }`}
                    >
                      <span
                        className={`num text-[22px] font-bold tracking-tight ${
                          best
                            ? "text-[#4ADE80]"
                            : r.quote?.stale
                            ? "text-[#5A5A5A] line-through"
                            : "text-[#EDEDED]"
                        }`}
                      >
                        {money(r.quote?.comparable)}
                      </span>
                      {best && (
                        <span className="block text-[11px] text-[#4ADE80] mt-1">
                          cheapest once compared fairly
                        </span>
                      )}
                      {r.quote?.stale && (
                        <span className="block text-[11px] text-[#FBBF24] mt-1">
                          priced the old job
                        </span>
                      )}
                      {r.quote?.needsReview && !r.quote?.stale && (
                        <span className="block text-[11px] text-[#60A5FA] mt-1">
                          worth checking
                        </span>
                      )}
                    </div>
                  </td>
                );
              })}
            </tr>

            {allExclusions.length > 0 && (
              <tr>
                <td
                  colSpan={rows.length + 1}
                  className="pt-8 pb-3 text-[12px] font-medium text-[#5A5A5A]"
                >
                  What each price does not cover
                </td>
              </tr>
            )}

            {allExclusions.map((ex) => (
              <tr key={ex} className="border-t border-[#242424]">
                <td className="py-2.5 pr-4 text-[12.5px] text-[#A1A1A1] align-top">
                  {ex}
                </td>
                {rows.map((r) => {
                  if (!r.quote)
                    return (
                      <td key={r.firmId} className="px-4 py-2.5 text-[#3A3A3A]">
                        —
                      </td>
                    );
                  const out = r.quote.exclusions.includes(ex);
                  return (
                    <td
                      key={r.firmId}
                      className={`px-4 py-2.5 ${r.quote.stale ? "opacity-40" : ""}`}
                    >
                      <span
                        className={`text-[12px] ${
                          out ? "text-[#F87171]" : "text-[#4ADE80]"
                        }`}
                      >
                        {out ? "not covered" : "covered"}
                      </span>
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Card>
  );
}

function Line({ label, note, children }) {
  return (
    <tr className="border-t border-[#242424]">
      <td className="py-3 pr-4 align-top">
        <div className="text-[13px] text-[#EDEDED]">{label}</div>
        <div className="text-[11.5px] text-[#5A5A5A] mt-0.5">{note}</div>
      </td>
      {children}
    </tr>
  );
}

function Status({ row }) {
  if (row.quote?.stale) return <Chip tone="warn">needs repricing</Chip>;
  if (row.quote) return <Chip tone="good">replied</Chip>;
  if (row.chaseCount > 0)
    return <Chip tone="neutral">chased {row.chaseCount}×</Chip>;
  return <Chip tone="neutral">no reply yet</Chip>;
}
EOF

cat > src/components/Feed.tsx << 'EOF'
import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, IconBox, I } from "./ui";

const DOT = {
  scope_changed: "bg-[#FBBF24]",
  quote_stale: "bg-[#FBBF24]",
  quote_valid: "bg-[#4ADE80]",
  quote_parsed: "bg-[#4ADE80]",
  reply_received: "bg-[#60A5FA]",
  reprice_requested: "bg-[#60A5FA]",
  parse_failed: "bg-[#F87171]",
};

export default function Feed({ projectId }) {
  const events = useQuery(api.events.feed, { projectId, limit: 30 });

  return (
    <Card className="h-fit">
      <div className="flex items-center gap-3 px-5 py-4 border-b border-[#2A2A2A]">
        <IconBox>{I.clock}</IconBox>
        <h2 className="text-[14.5px] font-semibold">Activity</h2>
      </div>
      <ol className="px-5 py-4 space-y-4 max-h-[560px] overflow-y-auto">
        {events?.map((e) => (
          <li key={e._id} className="flex gap-3">
            <span
              className={`mt-1.5 h-1.5 w-1.5 rounded-full shrink-0 ${
                DOT[e.type] ?? "bg-[#3A3A3A]"
              }`}
            />
            <div className="min-w-0">
              <p className="text-[12.5px] text-[#C9C9C9] leading-snug">
                {e.summary}
              </p>
              <p className="text-[11px] text-[#5A5A5A] mt-1">
                {new Date(e.createdAt).toLocaleString(undefined, {
                  month: "short",
                  day: "numeric",
                  hour: "numeric",
                  minute: "2-digit",
                })}
              </p>
            </div>
          </li>
        ))}
        {events && events.length === 0 && (
          <li className="text-[12.5px] text-[#5A5A5A]">
            Nothing yet. Ask the companies for a price to begin.
          </li>
        )}
      </ol>
    </Card>
  );
}
EOF

cat > src/components/Inbox.tsx << 'EOF'
import { useState } from "react";
import { useAction, useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, Chip, IconBox, Ghost, I } from "./ui";

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
    <Card>
      <div className="flex flex-wrap items-center gap-4 px-5 py-4 border-b border-[#2A2A2A]">
        <IconBox>{I.mail}</IconBox>
        <div className="min-w-0">
          <h2 className="text-[14.5px] font-semibold">This job's inbox</h2>
          <p className="text-[12px] text-[#5A5A5A] mt-0.5 break-all">
            {job.inboxAddress ?? "not created yet"}
          </p>
        </div>
        <div className="ml-auto flex flex-wrap gap-2">
          {!job.inboxAddress && (
            <Ghost disabled={!!busy} onClick={() => run("inbox", () => ensure({ jobId }))}>
              {busy === "inbox" ? "Creating…" : "Create inbox"}
            </Ghost>
          )}
          <Ghost disabled={!!busy} onClick={() => run("invite", () => send({ jobId }))}>
            {busy === "invite" ? "Sending…" : "Ask for prices"}
          </Ghost>
          <Ghost disabled={!!busy} onClick={() => run("chase", () => send({ jobId, chase: true }))}>
            {busy === "chase" ? "Sending…" : "Chase quiet ones"}
          </Ghost>
          <Ghost disabled={!!busy} onClick={() => run("reprice", () => reprice({ jobId }))}>
            {busy === "reprice" ? "Sending…" : "Ask to reprice"}
          </Ghost>
        </div>
      </div>

      {err && (
        <p className="px-5 pt-4 text-[12.5px] text-[#F87171]">{err}</p>
      )}

      <div className="px-5 py-2 divide-y divide-[#242424] max-h-[380px] overflow-y-auto">
        {threads?.length ? (
          threads.map((m) => (
            <div key={m._id} className="py-3.5 flex gap-4">
              <Chip tone={m.direction === "in" ? "good" : "neutral"}>
                {m.direction === "in" ? "in" : "out"}
              </Chip>
              <div className="min-w-0">
                <p className="text-[13px]">
                  {m.direction === "in" ? m.firmName : `To ${m.firmName}`}
                  <span className="text-[#5A5A5A]">
                    {" · "}
                    {m.subject ?? "(no subject)"}
                  </span>
                </p>
                <p className="text-[12.5px] text-[#A1A1A1] mt-1.5 leading-relaxed line-clamp-2 whitespace-pre-line">
                  {m.body.slice(0, 200)}
                </p>
              </div>
            </div>
          ))
        ) : (
          <p className="py-6 text-[12.5px] text-[#5A5A5A]">
            No email yet. Ask the companies for a price to begin.
          </p>
        )}
      </div>
    </Card>
  );
}
EOF

cat > src/components/ReadDoc.tsx << 'EOF'
import { useState } from "react";
import { useAction } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, IconBox, Primary, I } from "./ui";

export default function ReadDoc({ jobId, rows }) {
  const read = useAction(api.firecrawl.readQuoteDocument);
  const [url, setUrl] = useState("");
  const [firmId, setFirmId] = useState(rows?.[0]?.firmId ?? "");
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState("");
  const [err, setErr] = useState("");

  const go = async () => {
    if (!url || !firmId) return;
    setBusy(true);
    setErr("");
    setMsg("");
    const name = rows.find((x) => x.firmId === firmId)?.firmName ?? "That company";
    try {
      const r = await read({ jobId, firmId, url });
      setMsg(
        `${name}: ${r.total != null ? "$" + r.total.toLocaleString() : "no total found"}` +
          (r.exclusions.length ? `, leaving out ${r.exclusions.join(", ")}` : "") +
          (r.needsReview ? ". Worth checking by hand." : "")
      );
      setUrl("");
    } catch (e) {
      setErr(String(e.message ?? e));
    }
    setBusy(false);
  };

  return (
    <Card>
      <div className="flex items-center gap-3 px-5 py-4 border-b border-[#2A2A2A]">
        <IconBox>{I.doc}</IconBox>
        <div>
          <h2 className="text-[14.5px] font-semibold">Read a quote document</h2>
          <p className="text-[12px] text-[#5A5A5A] mt-0.5">
            PDFs that arrive by email are read without being asked
          </p>
        </div>
      </div>

      <div className="p-5 flex flex-wrap gap-3">
        <select
          value={firmId}
          onChange={(e) => setFirmId(e.target.value)}
          className="text-[13.5px] rounded-xl px-3.5 py-2.5 bg-[#242424] text-[#EDEDED]
            border border-[#2E2E2E] hover:border-[#3A3A3A] transition"
        >
          {rows?.map((r) => (
            <option key={r.firmId} value={r.firmId}>
              {r.firmName}
            </option>
          ))}
        </select>
        <input
          value={url}
          onChange={(e) => setUrl(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && go()}
          placeholder="https://…/quote.pdf"
          className="flex-1 min-w-[260px] text-[13.5px] rounded-xl px-4 py-2.5
            bg-[#242424] text-[#EDEDED] border border-[#2E2E2E]
            focus:border-[#2F7FFF] outline-none transition"
        />
        <Primary onClick={go} disabled={busy || !url}>
          {busy ? "Reading…" : "Read it"}
        </Primary>
      </div>

      {(msg || err) && (
        <p
          className={`px-5 pb-5 text-[12.5px] ${
            err ? "text-[#F87171]" : "text-[#4ADE80]"
          }`}
        >
          {err || msg}
        </p>
      )}
    </Card>
  );
}
EOF

echo "dark dashboard in"
