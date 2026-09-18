#!/bin/bash
# Bidzy: strict grid alignment + all sidebar pages.
set -e
[ -d convex/quoteEngine ] || { echo "Run from the bidzy project root."; exit 1; }

# ---------- shared primitives, on a strict 4px scale ----------
cat > src/components/ui.tsx << 'EOF'
export const PAD = "px-6";
export const HEAD_H = "h-[64px]";

export function Card({ children, className = "" }) {
  return (
    <div className={`bg-[#1F1F1F] border border-[#2E2E2E] rounded-2xl ${className}`}>
      {children}
    </div>
  );
}

// Every card header is the same height with the same padding, so cards
// sitting side by side line up on the same baselines.
export function CardHead({ icon, title, note, right }) {
  return (
    <div className={`${HEAD_H} ${PAD} flex items-center gap-3 border-b border-[#2A2A2A]`}>
      {icon && <IconBox>{icon}</IconBox>}
      <div className="min-w-0">
        <h2 className="text-[14px] font-semibold leading-5">{title}</h2>
        {note && (
          <p className="text-[12px] text-[#5A5A5A] leading-4 mt-0.5 truncate">
            {note}
          </p>
        )}
      </div>
      {right && <div className="ml-auto flex items-center gap-2">{right}</div>}
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
    <span
      className={`inline-flex items-center h-[22px] px-2 rounded-md text-[11px] font-medium leading-none ${tones[tone]}`}
    >
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
      className="h-10 px-4 rounded-xl text-[13px] font-semibold bg-[#2F7FFF] text-white
        hover:bg-[#1F6FEF] transition disabled:bg-[#2A2A2A] disabled:text-[#5A5A5A]"
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
      className="h-10 px-4 rounded-xl text-[13px] font-medium bg-[#242424] text-[#C9C9C9]
        border border-[#2E2E2E] hover:bg-[#2C2C2C] hover:text-white transition
        disabled:opacity-40"
    >
      {children}
    </button>
  );
}

export function Empty({ children }) {
  return (
    <div className="px-6 py-14 text-center text-[13px] text-[#5A5A5A]">
      {children}
    </div>
  );
}

export const money = (n) =>
  n == null ? "—" : "$" + n.toLocaleString(undefined, { maximumFractionDigits: 0 });

export const when = (t) =>
  new Date(t).toLocaleString(undefined, {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });

const s = (d) => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor"
    strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">{d}</svg>
);

export const I = {
  home: s(<><path d="M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z" /></>),
  mail: s(<><rect x="3" y="5" width="18" height="14" rx="2" /><path d="m3 7 9 6 9-6" /></>),
  doc: s(<><path d="M14 3v5h5" /><path d="M14 3H6a1 1 0 0 0-1 1v16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V8z" /></>),
  scale: s(<><path d="M12 3v18M5 7h14M7 7l-3 7h6zM17 7l-3 7h6z" /></>),
  clock: s(<><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 2" /></>),
  alert: s(<><path d="M12 8v5M12 17h.01" /><circle cx="12" cy="12" r="9" /></>),
  wallet: s(<><rect x="3" y="6" width="18" height="13" rx="2" /><path d="M3 10h18M17 14h.01" /></>),
  search: s(<><circle cx="11" cy="11" r="7" /><path d="m20 20-3.5-3.5" /></>),
};
EOF

# ---------- app shell with page switching ----------
cat > src/App.tsx from_here_placeholder 2>/dev/null || true
cat > src/App.tsx << 'EOF'
import { useState } from "react";
import { useQuery } from "convex/react";
import { api } from "../convex/_generated/api";
import Sidebar from "./components/Sidebar";
import Header from "./components/Header";
import ComparePage from "./pages/Compare";
import InboxPage from "./pages/InboxPage";
import DocsPage from "./pages/DocsPage";
import ActivityPage from "./pages/ActivityPage";
import ProjectsPage from "./pages/ProjectsPage";
import BudgetPage from "./pages/BudgetPage";

const TITLES = {
  compare: ["Price comparison", "Every price, compared like for like."],
  inbox: ["Inbox", "Companies reply here. They never sign in."],
  docs: ["Documents", "Quote PDFs, read into numbers."],
  activity: ["Activity", "Everything that has happened on this job."],
  projects: ["Projects", "Work you are getting priced."],
  budget: ["Budget", "What this job will really cost."],
};

export default function App() {
  const [page, setPage] = useState("compare");
  const projects = useQuery(api.projects.list);
  const project = projects?.[0];
  const jobs = useQuery(
    api.jobs.listByProject,
    project ? { projectId: project._id } : "skip"
  );
  const job = jobs?.[0];

  if (projects === undefined) return <Splash text="Loading" />;
  if (!project) return <Splash text="No project yet. Run the seed to start one." />;

  const [title, note] = TITLES[page];

  return (
    <div className="min-h-screen bg-[#171717] lg:p-3">
      <div className="lg:flex lg:gap-3">
        <Sidebar project={project} job={job} page={page} onNavigate={setPage} />
        <div className="flex-1 min-w-0 bg-[#1A1A1A] lg:rounded-3xl lg:border lg:border-[#2A2A2A] overflow-hidden">
          <Header
            project={project}
            title={title}
            note={note}
            showScopeAction={page === "compare"}
          />
          <main className="px-6 pb-8">
            {!job ? (
              <Splash text="No job on this project yet." />
            ) : page === "compare" ? (
              <ComparePage jobId={job._id} project={project} />
            ) : page === "inbox" ? (
              <InboxPage job={job} jobId={job._id} />
            ) : page === "docs" ? (
              <DocsPage jobId={job._id} />
            ) : page === "activity" ? (
              <ActivityPage projectId={project._id} />
            ) : page === "projects" ? (
              <ProjectsPage projects={projects} jobs={jobs} />
            ) : (
              <BudgetPage jobId={job._id} />
            )}
          </main>
        </div>
      </div>
    </div>
  );
}

function Splash({ text }) {
  return (
    <div className="min-h-[60vh] grid place-items-center text-[#5A5A5A] text-sm">
      {text}
    </div>
  );
}
EOF

cat > src/components/Sidebar.tsx << 'EOF'
import { I } from "./ui";

export default function Sidebar({ job, page, onNavigate }) {
  return (
    <aside className="hidden lg:flex w-[232px] shrink-0 flex-col py-6 px-4">
      <div className="h-9 flex items-center gap-2.5 px-2 mb-8">
        <div className="h-9 w-9 rounded-xl bg-[#2F7FFF] grid place-items-center shrink-0">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.2" strokeLinecap="round">
            <path d="M4 18 12 5l8 13" /><path d="M8 18h8" />
          </svg>
        </div>
        <span className="text-[17px] font-bold tracking-tight">Bidzy</span>
      </div>

      <Group label="This job" />
      <Item id="compare" icon={I.scale} page={page} go={onNavigate}>Compare prices</Item>
      <Item id="inbox" icon={I.mail} page={page} go={onNavigate}>Inbox</Item>
      <Item id="docs" icon={I.doc} page={page} go={onNavigate}>Documents</Item>
      <Item id="activity" icon={I.clock} page={page} go={onNavigate}>Activity</Item>

      <Group label="General" />
      <Item id="projects" icon={I.home} page={page} go={onNavigate}>Projects</Item>
      <Item id="budget" icon={I.wallet} page={page} go={onNavigate}>Budget</Item>

      <div className="mt-auto pt-8">
        <div className="rounded-2xl bg-[#1F1F1F] border border-[#2E2E2E] p-4">
          <p className="text-[12px] text-[#A1A1A1] leading-5">Companies reply to</p>
          <p className="text-[12px] text-[#EDEDED] break-all mt-1 leading-5">
            {job?.inboxAddress ?? "no inbox yet"}
          </p>
          <p className="text-[11px] text-[#5A5A5A] mt-2 leading-5">
            They never sign in. It's just email.
          </p>
        </div>
      </div>
    </aside>
  );
}

function Group({ label }) {
  return (
    <p className="h-8 flex items-end text-[10px] font-semibold tracking-[0.12em] uppercase text-[#5A5A5A] px-3 mt-4 mb-1">
      {label}
    </p>
  );
}

function Item({ id, icon, children, page, go }) {
  const active = page === id;
  return (
    <button
      onClick={() => go(id)}
      className={`h-10 w-full flex items-center gap-3 px-3 rounded-xl text-[13.5px] mb-0.5 text-left transition ${
        active
          ? "bg-[#242424] text-white font-medium"
          : "text-[#A1A1A1] hover:text-[#EDEDED] hover:bg-[#1F1F1F]"
      }`}
    >
      <span className={`shrink-0 ${active ? "text-[#2F7FFF]" : ""}`}>{icon}</span>
      {children}
    </button>
  );
}
EOF

cat > src/components/Header.tsx << 'EOF'
import { useMutation, useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { useState } from "react";
import { I, Primary, Ghost } from "./ui";

export default function Header({ project, title, note, showScopeAction }) {
  const change = useMutation(api.projects.changeScope);
  const reset = useMutation(api.projects.resetStale);
  const addenda = useQuery(api.projects.addenda, { projectId: project._id });
  const [busy, setBusy] = useState(false);
  const changed = (addenda?.length ?? 0) > 0;

  return (
    <div className="px-6 pt-6 pb-6 border-b border-[#2A2A2A]">
      <div className="h-10 flex items-center gap-3 mb-7">
        <div className="h-10 flex items-center gap-2.5 bg-[#1F1F1F] border border-[#2E2E2E] rounded-xl px-3.5 w-full max-w-[360px] text-[#5A5A5A]">
          {I.search}
          <span className="text-[13px] truncate">Search companies, prices, email</span>
        </div>
        <div className="ml-auto flex items-center gap-2.5">
          <div className="hidden xl:flex h-10 items-center gap-2 bg-[#1F1F1F] border border-[#2E2E2E] rounded-xl px-3.5 text-[12.5px] text-[#A1A1A1]">
            {I.home}
            <span className="truncate max-w-[280px]">{project.scopeNote}</span>
          </div>
          <div className="h-10 w-10 rounded-full bg-[#2A2A2A] grid place-items-center text-[12px] font-semibold text-[#A1A1A1] shrink-0">
            H
          </div>
        </div>
      </div>

      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-[25px] font-bold tracking-tight leading-8">{title}</h1>
          <p className="text-[13.5px] text-[#A1A1A1] mt-1.5 leading-5">
            {project.name}, {project.client} — {note}
          </p>
        </div>
        {showScopeAction && (
          <div className="flex gap-2.5">
            {changed && (
              <Ghost
                disabled={busy}
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
        )}
      </div>
    </div>
  );
}
EOF

mkdir -p src/pages

# ---------- compare ----------
cat > src/pages/Compare.tsx << 'EOF'
import Board from "../components/Board";
import Stats from "../components/Stats";
import Feed from "../components/Feed";

export default function ComparePage({ jobId, project }) {
  return (
    <div className="pt-6">
      <Stats jobId={jobId} />
      <div className="grid grid-cols-1 2xl:grid-cols-[minmax(0,1fr)_332px] gap-6 mt-6">
        <Board jobId={jobId} />
        <Feed projectId={project._id} limit={14} />
      </div>
    </div>
  );
}
EOF

cat > src/components/Stats.tsx << 'EOF'
import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, Chip, IconBox, I, money } from "./ui";

export default function Stats({ jobId }) {
  const d = useQuery(api.jobs.board, { jobId });
  if (!d) return <div className="h-[148px]" />;

  const gap =
    d.lowest != null && d.headlineLowest != null ? d.lowest - d.headlineLowest : null;

  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
      <Stat
        icon={I.scale}
        label="Best real cost"
        value={money(d.lowest)}
        foot={d.lowestParty ?? "no valid price yet"}
        accent
      />
      <Stat
        icon={I.alert}
        label="Cheapest on paper"
        value={money(d.headlineLowest)}
        dim
        foot={d.headlineParty ?? "waiting on prices"}
        chip={
          d.headlineMisleads && gap != null ? (
            <Chip tone="warn">really {money(Math.abs(gap))} more</Chip>
          ) : null
        }
      />
      <Stat
        icon={I.mail}
        label="Replies"
        value={
          <>
            {d.quotedCount}
            <span className="text-[#5A5A5A]">/{d.invitedCount}</span>
          </>
        }
        chip={
          d.staleCount > 0 ? (
            <Chip tone="warn">{d.staleCount} need repricing</Chip>
          ) : (
            <Chip tone="good">all current</Chip>
          )
        }
      />
    </div>
  );
}

function Stat({ icon, label, value, foot, chip, accent, dim }) {
  return (
    <Card className="p-6 flex flex-col">
      <div className="h-9 flex items-center gap-3 mb-5">
        <IconBox>{icon}</IconBox>
        <span className="text-[13.5px] font-semibold">{label}</span>
      </div>
      <p
        className={`num text-[30px] font-bold tracking-tight leading-9 ${
          accent ? "text-[#4ADE80]" : dim ? "text-[#A1A1A1]" : "text-[#EDEDED]"
        }`}
      >
        {value}
      </p>
      <div className="h-[22px] flex items-center gap-2 mt-3">
        {chip}
        {foot && <span className="text-[12.5px] text-[#A1A1A1] truncate">{foot}</span>}
      </div>
    </Card>
  );
}
EOF

# ---------- board, strictly gridded ----------
cat > src/components/Board.tsx << 'EOF'
import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, CardHead, Chip, I, money } from "./ui";

export default function Board({ jobId }) {
  const d = useQuery(api.jobs.board, { jobId });
  if (!d)
    return (
      <Card>
        <CardHead icon={I.scale} title="Price comparison" note="loading" />
      </Card>
    );

  const {
    rows, allExclusions, lowest, lowestParty,
    headlineLowest, headlineParty, headlineMisleads,
    previousBest, lowestMoved, staleCount,
  } = d;

  const colW = `${Math.floor(76 / Math.max(rows.length, 1))}%`;

  return (
    <Card>
      <CardHead
        icon={I.scale}
        title="Price comparison"
        note="Missing work is priced from what the others charged"
      />

      {(lowestMoved || headlineMisleads) && (
        <div className="mx-6 mt-6 rounded-xl bg-[#2E2410] border border-[#443415] px-4 py-3.5">
          <p className="text-[13.5px] text-[#FBBF24] leading-6">
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

      <div className="overflow-x-auto p-6">
        <table className="w-full table-fixed border-collapse min-w-[760px]">
          <colgroup>
            <col style={{ width: "24%" }} />
            {rows.map((r) => (
              <col key={r.firmId} style={{ width: colW }} />
            ))}
          </colgroup>

          <thead>
            <tr>
              <th className="h-[76px] align-top text-left pb-4">
                <span className="text-[12px] font-medium text-[#5A5A5A]">
                  Company
                </span>
              </th>
              {rows.map((r) => (
                <th key={r.firmId} className="h-[76px] align-top text-left pb-4 pl-5">
                  <div
                    className={`text-[14px] font-semibold leading-5 truncate ${
                      r.quote?.stale ? "text-[#5A5A5A]" : "text-[#EDEDED]"
                    }`}
                  >
                    {r.firmName}
                  </div>
                  <div className="mt-2 flex flex-wrap gap-1.5 min-h-[22px]">
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
                  className={`py-4 pl-5 align-top ${r.quote?.stale ? "opacity-40" : ""}`}
                >
                  <span className="num text-[15px] text-[#A1A1A1] leading-6">
                    {money(r.quote?.total)}
                  </span>
                </td>
              ))}
            </Line>

            <Line label="Missing work" note="priced from the others">
              {rows.map((r) => (
                <td
                  key={r.firmId}
                  className={`py-4 pl-5 align-top ${r.quote?.stale ? "opacity-40" : ""}`}
                >
                  {r.quote ? (
                    r.quote.hidden > 0 ? (
                      <>
                        <span className="num text-[15px] text-[#FBBF24] leading-6">
                          + {money(r.quote.hidden)}
                        </span>
                        <span className="block text-[11.5px] text-[#5A5A5A] mt-1.5 leading-5">
                          {r.quote.gaps.map((g) => g.label).join(", ")}
                        </span>
                      </>
                    ) : (
                      <span className="text-[12.5px] text-[#5A5A5A] leading-6">
                        nothing left out
                      </span>
                    )
                  ) : (
                    <span className="text-[#3A3A3A] leading-6">—</span>
                  )}
                </td>
              ))}
            </Line>

            <tr className="border-t border-[#242424]">
              <td className="py-5 pr-5 align-top">
                <div className="text-[13.5px] font-semibold leading-5">Real cost</div>
                <div className="text-[11.5px] text-[#5A5A5A] leading-4 mt-0.5">
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
                    className={`py-5 pl-5 align-top ${r.quote?.stale ? "opacity-40" : ""}`}
                  >
                    <div
                      className={`rounded-xl px-4 py-3.5 border min-h-[84px] ${
                        best
                          ? "bg-[#0F2C1F] border-[#1B4A33]"
                          : "bg-[#242424] border-[#2E2E2E]"
                      }`}
                    >
                      <span
                        className={`num block text-[22px] font-bold tracking-tight leading-7 ${
                          best
                            ? "text-[#4ADE80]"
                            : r.quote?.stale
                            ? "text-[#5A5A5A] line-through"
                            : "text-[#EDEDED]"
                        }`}
                      >
                        {money(r.quote?.comparable)}
                      </span>
                      <span className="block text-[11px] mt-1.5 leading-4 min-h-[16px]">
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
                <td className="h-11 pr-5 text-[12.5px] text-[#A1A1A1] align-middle">
                  {ex}
                </td>
                {rows.map((r) => {
                  if (!r.quote)
                    return (
                      <td key={r.firmId} className="h-11 pl-5 text-[#3A3A3A] align-middle">
                        —
                      </td>
                    );
                  const out = r.quote.exclusions.includes(ex);
                  return (
                    <td
                      key={r.firmId}
                      className={`h-11 pl-5 align-middle ${r.quote.stale ? "opacity-40" : ""}`}
                    >
                      <span className={`text-[12px] ${out ? "text-[#F87171]" : "text-[#4ADE80]"}`}>
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
      <td className="py-4 pr-5 align-top">
        <div className="text-[13px] text-[#EDEDED] leading-6">{label}</div>
        <div className="text-[11.5px] text-[#5A5A5A] leading-4 mt-0.5">{note}</div>
      </td>
      {children}
    </tr>
  );
}

function Status({ row }) {
  if (row.quote?.stale) return <Chip tone="warn">needs repricing</Chip>;
  if (row.quote) return <Chip tone="good">replied</Chip>;
  if (row.chaseCount > 0) return <Chip tone="neutral">chased {row.chaseCount}×</Chip>;
  return <Chip tone="neutral">no reply yet</Chip>;
}
EOF

cat > src/components/Feed.tsx << 'EOF'
import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, CardHead, Empty, I, when } from "./ui";

const DOT = {
  scope_changed: "bg-[#FBBF24]",
  quote_stale: "bg-[#FBBF24]",
  quote_valid: "bg-[#4ADE80]",
  quote_parsed: "bg-[#4ADE80]",
  reply_received: "bg-[#60A5FA]",
  reprice_requested: "bg-[#60A5FA]",
  parse_failed: "bg-[#F87171]",
};

export default function Feed({ projectId, limit = 30, full }) {
  const events = useQuery(api.events.feed, { projectId, limit });

  return (
    <Card className="h-fit">
      <CardHead icon={I.clock} title="Activity" />
      {events && events.length === 0 ? (
        <Empty>Nothing yet. Ask the companies for a price to begin.</Empty>
      ) : (
        <ol className={`px-6 py-5 space-y-5 ${full ? "" : "max-h-[548px] overflow-y-auto"}`}>
          {events?.map((e) => (
            <li key={e._id} className="flex gap-3">
              <span
                className={`mt-[7px] h-1.5 w-1.5 rounded-full shrink-0 ${
                  DOT[e.type] ?? "bg-[#3A3A3A]"
                }`}
              />
              <div className="min-w-0">
                <p className="text-[12.5px] text-[#C9C9C9] leading-5">{e.summary}</p>
                <p className="text-[11px] text-[#5A5A5A] mt-1 leading-4">
                  {when(e.createdAt)}
                </p>
              </div>
            </li>
          ))}
        </ol>
      )}
    </Card>
  );
}
EOF

# ---------- inbox page ----------
cat > src/pages/InboxPage.tsx << 'EOF'
import { useState } from "react";
import { useAction, useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, CardHead, Chip, Ghost, Empty, I, when } from "../components/ui";

export default function InboxPage({ job, jobId }) {
  const send = useAction(api.agentmail.sendInvitations);
  const reprice = useAction(api.agentmail.requestReprice);
  const ensure = useAction(api.agentmail.ensureInbox);
  const threads = useQuery(api.mail.threadsByJob, { jobId });
  const [busy, setBusy] = useState("");
  const [err, setErr] = useState("");
  const [open, setOpen] = useState(null);

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

  const selected = threads?.find((m) => m._id === open) ?? threads?.[0];

  return (
    <div className="pt-6 space-y-6">
      <Card>
        <CardHead
          icon={I.mail}
          title={job.inboxAddress ?? "No inbox yet"}
          note="Companies reply to this address like any other email"
          right={
            <div className="flex flex-wrap gap-2">
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
          }
        />
        {err && <p className="px-6 py-4 text-[12.5px] text-[#F87171]">{err}</p>}
      </Card>

      <div className="grid grid-cols-1 xl:grid-cols-[380px_minmax(0,1fr)] gap-6">
        <Card className="h-fit">
          <CardHead icon={I.mail} title="Messages" note={`${threads?.length ?? 0} in this thread`} />
          {threads && threads.length === 0 ? (
            <Empty>No email yet.</Empty>
          ) : (
            <ul className="divide-y divide-[#242424] max-h-[560px] overflow-y-auto">
              {threads?.map((m) => (
                <li key={m._id}>
                  <button
                    onClick={() => setOpen(m._id)}
                    className={`w-full text-left px-6 py-4 transition ${
                      selected?._id === m._id ? "bg-[#242424]" : "hover:bg-[#1C1C1C]"
                    }`}
                  >
                    <div className="flex items-center gap-2.5 mb-1.5">
                      <Chip tone={m.direction === "in" ? "good" : "neutral"}>
                        {m.direction === "in" ? "in" : "out"}
                      </Chip>
                      <span className="text-[13px] font-medium truncate">
                        {m.firmName}
                      </span>
                      <span className="ml-auto text-[11px] text-[#5A5A5A] shrink-0">
                        {when(m.createdAt)}
                      </span>
                    </div>
                    <p className="text-[12.5px] text-[#A1A1A1] truncate leading-5">
                      {m.subject ?? "(no subject)"}
                    </p>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </Card>

        <Card className="h-fit">
          <CardHead
            icon={I.doc}
            title={selected?.subject ?? "Nothing selected"}
            note={
              selected
                ? `${selected.direction === "in" ? "From" : "To"} ${selected.firmName} · ${when(selected.createdAt)}`
                : undefined
            }
          />
          {selected ? (
            <pre className="px-6 py-6 text-[13px] text-[#C9C9C9] leading-6 whitespace-pre-wrap font-sans">
              {selected.body}
            </pre>
          ) : (
            <Empty>Pick a message to read it.</Empty>
          )}
        </Card>
      </div>
    </div>
  );
}
EOF

# ---------- documents page ----------
cat > src/pages/DocsPage.tsx << 'EOF'
import { useState } from "react";
import { useAction, useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, CardHead, Chip, Primary, Empty, I, money } from "../components/ui";

export default function DocsPage({ jobId }) {
  const d = useQuery(api.jobs.board, { jobId });
  const read = useAction(api.firecrawl.readQuoteDocument);
  const [url, setUrl] = useState("");
  const [firmId, setFirmId] = useState("");
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState("");
  const [err, setErr] = useState("");

  const rows = d?.rows ?? [];
  const active = firmId || rows[0]?.firmId || "";

  const go = async () => {
    if (!url || !active) return;
    setBusy(true);
    setErr("");
    setMsg("");
    const name = rows.find((x) => x.firmId === active)?.firmName ?? "That company";
    try {
      const r = await read({ jobId, firmId: active, url });
      setMsg(
        `${name}: ${r.total != null ? money(r.total) : "no total found"}` +
          (r.exclusions.length ? `, leaving out ${r.exclusions.join(", ")}` : "") +
          (r.needsReview ? ". Worth checking by hand." : "")
      );
      setUrl("");
    } catch (e) {
      setErr(String(e.message ?? e));
    }
    setBusy(false);
  };

  const withDocs = rows.filter((r) => r.quote?.lineItems?.length);

  return (
    <div className="pt-6 space-y-6">
      <Card>
        <CardHead
          icon={I.doc}
          title="Read a quote document"
          note="PDFs that arrive by email are read without being asked"
        />
        <div className="p-6 flex flex-wrap gap-3">
          <select
            value={active}
            onChange={(e) => setFirmId(e.target.value)}
            className="h-10 text-[13.5px] rounded-xl px-3.5 bg-[#242424] text-[#EDEDED]
              border border-[#2E2E2E] hover:border-[#3A3A3A] transition"
          >
            {rows.map((r) => (
              <option key={r.firmId} value={r.firmId}>{r.firmName}</option>
            ))}
          </select>
          <input
            value={url}
            onChange={(e) => setUrl(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && go()}
            placeholder="https://…/quote.pdf"
            className="h-10 flex-1 min-w-[260px] text-[13.5px] rounded-xl px-4
              bg-[#242424] text-[#EDEDED] border border-[#2E2E2E]
              focus:border-[#2F7FFF] outline-none transition"
          />
          <Primary onClick={go} disabled={busy || !url}>
            {busy ? "Reading…" : "Read it"}
          </Primary>
        </div>
        {(msg || err) && (
          <p className={`px-6 pb-6 text-[12.5px] leading-5 ${err ? "text-[#F87171]" : "text-[#4ADE80]"}`}>
            {err || msg}
          </p>
        )}
      </Card>

      <Card>
        <CardHead icon={I.scale} title="What we read from each quote" />
        {withDocs.length === 0 ? (
          <Empty>Nothing read yet.</Empty>
        ) : (
          <div className="divide-y divide-[#242424]">
            {withDocs.map((r) => (
              <div key={r.firmId} className="px-6 py-5">
                <div className="flex flex-wrap items-center gap-3 mb-4">
                  <span className="text-[14px] font-semibold">{r.firmName}</span>
                  <span className="num text-[14px] text-[#A1A1A1]">
                    {money(r.quote.total)}
                  </span>
                  {r.quote.needsReview && <Chip tone="info">worth checking</Chip>}
                  {r.quote.stale && <Chip tone="warn">priced the old job</Chip>}
                </div>
                <div className="grid sm:grid-cols-2 gap-x-8 gap-y-2">
                  {r.quote.lineItems.map((li, i) => (
                    <div key={i} className="flex justify-between gap-4 h-6 items-center">
                      <span className="text-[12.5px] text-[#A1A1A1] truncate">
                        {li.label}
                      </span>
                      <span className="num text-[12.5px] text-[#C9C9C9] shrink-0">
                        {money(li.amount)}
                      </span>
                    </div>
                  ))}
                </div>
                {r.quote.exclusions.length > 0 && (
                  <p className="text-[12px] text-[#F87171] mt-4 leading-5">
                    Not covered: {r.quote.exclusions.join(", ")}
                  </p>
                )}
              </div>
            ))}
          </div>
        )}
      </Card>
    </div>
  );
}
EOF

# ---------- activity page ----------
cat > src/pages/ActivityPage.tsx << 'EOF'
import Feed from "../components/Feed";

export default function ActivityPage({ projectId }) {
  return (
    <div className="pt-6 max-w-[760px]">
      <Feed projectId={projectId} limit={60} full />
    </div>
  );
}
EOF

# ---------- projects page ----------
cat > src/pages/ProjectsPage.tsx << 'EOF'
import { Card, CardHead, Chip, I, when } from "../components/ui";

export default function ProjectsPage({ projects, jobs }) {
  return (
    <div className="pt-6 max-w-[900px]">
      <Card>
        <CardHead icon={I.home} title="Projects" note="Work you are getting priced" />
        <div className="divide-y divide-[#242424]">
          {projects.map((p) => (
            <div key={p._id} className="px-6 py-5 flex flex-wrap items-center gap-4">
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2.5">
                  <span className="text-[14px] font-semibold">{p.name}</span>
                  <Chip tone={p.revision > 1 ? "warn" : "good"}>
                    {p.revision > 1 ? "job changed" : "as first described"}
                  </Chip>
                </div>
                <p className="text-[12.5px] text-[#A1A1A1] mt-1.5 leading-5">
                  {p.client} · {p.scopeNote}
                </p>
              </div>
              <div className="text-right shrink-0">
                <p className="text-[12.5px] text-[#C9C9C9]">
                  {jobs?.filter((j) => j.projectId === p._id).length ?? 0} job
                </p>
                <p className="text-[11px] text-[#5A5A5A] mt-1">{when(p.createdAt)}</p>
              </div>
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
}
EOF

# ---------- budget page ----------
cat > src/pages/BudgetPage.tsx << 'EOF'
import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, CardHead, Chip, Empty, I, money } from "../components/ui";

export default function BudgetPage({ jobId }) {
  const d = useQuery(api.jobs.board, { jobId });
  if (!d) return <div className="pt-6" />;

  const winner = d.rows.find(
    (r) => r.quote?.comparable === d.lowest && !r.quote?.stale
  );
  const spread = d.rows
    .filter((r) => r.quote?.comparable != null && !r.quote.stale)
    .map((r) => r.quote.comparable);
  const worst = spread.length ? Math.max(...spread) : null;

  return (
    <div className="pt-6 grid grid-cols-1 xl:grid-cols-[minmax(0,1fr)_360px] gap-6">
      <Card>
        <CardHead
          icon={I.wallet}
          title="If you go with the best price"
          note={winner ? winner.firmName : "no valid price yet"}
        />
        {!winner ? (
          <Empty>No valid price to budget against yet.</Empty>
        ) : (
          <div className="p-6">
            <p className="num text-[38px] font-bold tracking-tight leading-none text-[#4ADE80]">
              {money(winner.quote.comparable)}
            </p>
            <p className="text-[12.5px] text-[#A1A1A1] mt-3 leading-5">
              Quoted {money(winner.quote.total)}
              {winner.quote.hidden > 0 &&
                `, plus ${money(winner.quote.hidden)} of work they left out`}
              .
            </p>

            <div className="mt-7 divide-y divide-[#242424] border-t border-[#242424]">
              {winner.quote.lineItems.map((li, i) => (
                <div key={i} className="h-11 flex items-center justify-between gap-4">
                  <span className="text-[13px] text-[#A1A1A1] truncate">{li.label}</span>
                  <span className="num text-[13px] text-[#C9C9C9] shrink-0">
                    {money(li.amount)}
                  </span>
                </div>
              ))}
              {winner.quote.hidden > 0 && (
                <div className="h-11 flex items-center justify-between gap-4">
                  <span className="text-[13px] text-[#FBBF24] truncate">
                    Work not covered, priced from the others
                  </span>
                  <span className="num text-[13px] text-[#FBBF24] shrink-0">
                    {money(winner.quote.hidden)}
                  </span>
                </div>
              )}
              <div className="h-14 flex items-center justify-between gap-4">
                <span className="text-[13.5px] font-semibold">Total to budget</span>
                <span className="num text-[16px] font-bold">
                  {money(winner.quote.comparable)}
                </span>
              </div>
            </div>
          </div>
        )}
      </Card>

      <Card className="h-fit">
        <CardHead icon={I.alert} title="What picking wrong would cost" />
        <div className="p-6 space-y-5">
          <Row
            label="Cheapest real cost"
            value={money(d.lowest)}
            tone="text-[#4ADE80]"
          />
          <Row label="Dearest real cost" value={money(worst)} />
          <Row
            label="Difference"
            value={
              worst != null && d.lowest != null ? money(worst - d.lowest) : "—"
            }
            tone="text-[#FBBF24]"
          />
          {d.headlineMisleads && (
            <p className="text-[12.5px] text-[#A1A1A1] leading-5 pt-2 border-t border-[#242424]">
              Going by the headline price alone would have picked{" "}
              {d.headlineParty}, which is{" "}
              {money(Math.abs(d.lowest - d.headlineLowest))} more once the
              missing work is priced in.
            </p>
          )}
          {d.staleCount > 0 && (
            <div className="pt-2">
              <Chip tone="warn">
                {d.staleCount} price{d.staleCount === 1 ? "" : "s"} excluded, job changed
              </Chip>
            </div>
          )}
        </div>
      </Card>
    </div>
  );
}

function Row({ label, value, tone = "text-[#EDEDED]" }) {
  return (
    <div className="flex items-center justify-between gap-4">
      <span className="text-[13px] text-[#A1A1A1]">{label}</span>
      <span className={`num text-[15px] font-semibold ${tone}`}>{value}</span>
    </div>
  );
}
EOF

rm -f src/components/Inbox.tsx src/components/ReadDoc.tsx
echo "pages + alignment done"
