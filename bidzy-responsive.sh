#!/bin/bash
# Works on a phone, a laptop and a wide monitor.
set -e
[ -d convex/quoteEngine ] || { echo "Run from the bidzy project root."; exit 1; }

# ---- mobile nav: the sidebar becomes a drawer ----
cat > src/components/Sidebar.tsx << 'EOF'
import { I } from "./ui";

const NAV = [
  ["This job", [
    ["compare", "Compare prices", "scale"],
    ["inbox", "Inbox", "mail"],
    ["docs", "Documents", "doc"],
    ["activity", "Activity", "clock"],
  ]],
  ["General", [
    ["projects", "Projects", "home"],
    ["budget", "Budget", "wallet"],
  ]],
];

export default function Sidebar({ job, page, onNavigate, open, onClose }) {
  return (
    <>
      {open && (
        <div
          onClick={onClose}
          className="lg:hidden fixed inset-0 z-30 bg-black/60 backdrop-blur-sm"
        />
      )}

      <aside
        className={`
          fixed lg:static inset-y-0 left-0 z-40 w-[264px] lg:w-[232px] shrink-0
          flex flex-col py-6 px-4 bg-[#171717] lg:bg-transparent
          border-r border-[#2A2A2A] lg:border-0
          transition-transform duration-200
          ${open ? "translate-x-0" : "-translate-x-full"} lg:translate-x-0
        `}
      >
        <div className="h-9 flex items-center gap-2.5 px-2 mb-8">
          <div className="h-9 w-9 rounded-xl bg-[#2F7FFF] grid place-items-center shrink-0">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.2" strokeLinecap="round">
              <path d="M4 18 12 5l8 13" /><path d="M8 18h8" />
            </svg>
          </div>
          <span className="text-[17px] font-bold tracking-tight">Bidzy</span>
        </div>

        {NAV.map(([label, items]) => (
          <div key={label}>
            <p className="h-8 flex items-end text-[10px] font-semibold tracking-[0.12em] uppercase text-[#5A5A5A] px-3 mt-4 mb-1">
              {label}
            </p>
            {items.map(([id, text, icon]) => (
              <button
                key={id}
                onClick={() => {
                  onNavigate(id);
                  onClose?.();
                }}
                className={`h-10 w-full flex items-center gap-3 px-3 rounded-xl text-[13.5px] mb-0.5 text-left transition ${
                  page === id
                    ? "bg-[#242424] text-white font-medium"
                    : "text-[#A1A1A1] hover:text-[#EDEDED] hover:bg-[#1F1F1F]"
                }`}
              >
                <span className={`shrink-0 ${page === id ? "text-[#2F7FFF]" : ""}`}>
                  {I[icon]}
                </span>
                {text}
              </button>
            ))}
          </div>
        ))}

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
    </>
  );
}
EOF

python3 - << 'PY'
p = "src/App.tsx"
s = open(p).read()
s = s.replace(
  'const [page, setPage] = useState("compare");',
  'const [page, setPage] = useState("compare");\n  const [navOpen, setNavOpen] = useState(false);'
)
s = s.replace(
  "<Sidebar project={project} job={job} page={page} onNavigate={setPage} />",
  "<Sidebar\n            project={project}\n            job={job}\n            page={page}\n            onNavigate={setPage}\n            open={navOpen}\n            onClose={() => setNavOpen(false)}\n          />"
)
s = s.replace(
  '            showScopeAction={page === "compare"}\n          />',
  '            showScopeAction={page === "compare"}\n            onMenu={() => setNavOpen(true)}\n          />'
)
s = s.replace(
  'className="px-6 pb-8"',
  'className="px-4 sm:px-6 pb-8"'
)
open(p, "w").write(s)
print("app wired for the drawer")
PY

python3 - << 'PY'
p = "src/components/Header.tsx"
s = open(p).read()
s = s.replace(
  "export default function Header({ project, title, note, showScopeAction }) {",
  "export default function Header({ project, title, note, showScopeAction, onMenu }) {"
)
s = s.replace(
  'className="px-6 pt-6 pb-6 border-b border-[#2A2A2A]"',
  'className="px-4 sm:px-6 pt-5 sm:pt-6 pb-5 sm:pb-6 border-b border-[#2A2A2A]"'
)
s = s.replace(
  '''      <div className="h-10 flex items-center gap-3 mb-7">
        <div className="h-10 flex items-center gap-2.5 bg-[#1F1F1F] border border-[#2E2E2E] rounded-xl px-3.5 w-full max-w-[360px] text-[#5A5A5A]">''',
  '''      <div className="h-10 flex items-center gap-3 mb-6 sm:mb-7">
        <button
          onClick={onMenu}
          aria-label="Open menu"
          className="lg:hidden h-10 w-10 shrink-0 rounded-xl bg-[#1F1F1F] border border-[#2E2E2E] grid place-items-center text-[#A1A1A1]"
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
            <path d="M4 7h16M4 12h16M4 17h16" />
          </svg>
        </button>
        <div className="hidden sm:flex h-10 items-center gap-2.5 bg-[#1F1F1F] border border-[#2E2E2E] rounded-xl px-3.5 w-full max-w-[360px] text-[#5A5A5A]">'''
)
s = s.replace(
  'className="text-[25px] font-bold tracking-tight leading-8"',
  'className="text-[21px] sm:text-[25px] font-bold tracking-tight leading-7 sm:leading-8"'
)
s = s.replace(
  'className="text-[13.5px] text-[#A1A1A1] mt-1.5 leading-5"',
  'className="text-[13px] sm:text-[13.5px] text-[#A1A1A1] mt-1.5 leading-5"'
)
open(p, "w").write(s)
print("header has a menu button")
PY

# ---- board: horizontal scroll hint + tighter padding on small screens ----
python3 - << 'PY'
p = "src/components/Board.tsx"
s = open(p).read()
s = s.replace(
  'className="overflow-x-auto p-6"',
  'className="overflow-x-auto p-4 sm:p-6"'
)
s = s.replace(
  'className="mx-6 mt-6 rounded-xl bg-[#2E2410]',
  'className="mx-4 sm:mx-6 mt-5 sm:mt-6 rounded-xl bg-[#2E2410]'
)
s = s.replace(
  'className="w-full table-fixed border-collapse min-w-[760px]"',
  'className="w-full table-fixed border-collapse min-w-[680px]"'
)
open(p, "w").write(s)
print("board scrolls cleanly on a phone")
PY

# ---- cards and grids collapse sensibly ----
python3 - << 'PY'
import re, pathlib

edits = {
  "src/components/ui.tsx": [
    ('export const PAD = "px-6";', 'export const PAD = "px-4 sm:px-6";'),
    ('`${HEAD_H} ${PAD} flex items-center gap-3 border-b border-[#2A2A2A]`',
     '`${HEAD_H} ${PAD} flex items-center gap-3 border-b border-[#2A2A2A] flex-wrap sm:flex-nowrap`'),
  ],
  "src/pages/Compare.tsx": [
    ('gap-6 mt-6', 'gap-5 sm:gap-6 mt-5 sm:mt-6'),
  ],
  "src/components/Stats.tsx": [
    ('className="grid grid-cols-1 md:grid-cols-3 gap-6"',
     'className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-5 sm:gap-6"'),
    ('<Card className="p-6 flex flex-col">', '<Card className="p-5 sm:p-6 flex flex-col">'),
    ('className="num text-[30px] font-bold tracking-tight leading-9',
     'className="num text-[26px] sm:text-[30px] font-bold tracking-tight leading-9'),
  ],
  "src/pages/InboxPage.tsx": [
    ('className="pt-6 space-y-6"', 'className="pt-5 sm:pt-6 space-y-5 sm:space-y-6"'),
    ('grid grid-cols-1 xl:grid-cols-[380px_minmax(0,1fr)] gap-6',
     'grid grid-cols-1 xl:grid-cols-[360px_minmax(0,1fr)] gap-5 sm:gap-6'),
    ('className="px-6 py-4 transition', 'className="px-4 sm:px-6 py-4 transition'),
    ('className="px-6 py-6 text-[13px]', 'className="px-4 sm:px-6 py-5 sm:py-6 text-[13px]'),
  ],
  "src/pages/DocsPage.tsx": [
    ('className="pt-6 space-y-6"', 'className="pt-5 sm:pt-6 space-y-5 sm:space-y-6"'),
    ('className="p-6 flex flex-wrap gap-3"', 'className="p-4 sm:p-6 flex flex-wrap gap-3"'),
    ('className="px-6 py-5"', 'className="px-4 sm:px-6 py-5"'),
    ('className="px-6 pb-6 text-[12.5px]', 'className="px-4 sm:px-6 pb-5 sm:pb-6 text-[12.5px]'),
  ],
  "src/pages/BudgetPage.tsx": [
    ('className="pt-6 grid grid-cols-1 xl:grid-cols-[minmax(0,1fr)_360px] gap-6"',
     'className="pt-5 sm:pt-6 grid grid-cols-1 xl:grid-cols-[minmax(0,1fr)_360px] gap-5 sm:gap-6"'),
    ('<div className="p-6">', '<div className="p-4 sm:p-6">'),
    ('className="p-6 space-y-5"', 'className="p-4 sm:p-6 space-y-5"'),
    ('className="num text-[38px]', 'className="num text-[32px] sm:text-[38px]'),
  ],
  "src/pages/ProjectsPage.tsx": [
    ('className="pt-6 max-w-[900px]"', 'className="pt-5 sm:pt-6 max-w-[900px]"'),
    ('className="px-6 py-5 flex flex-wrap', 'className="px-4 sm:px-6 py-5 flex flex-wrap'),
  ],
  "src/pages/ActivityPage.tsx": [
    ('className="pt-6 max-w-[760px]"', 'className="pt-5 sm:pt-6 max-w-[760px]"'),
  ],
  "src/components/Feed.tsx": [
    ('className={`px-6 py-5 space-y-5', 'className={`px-4 sm:px-6 py-5 space-y-5'),
  ],
}

for path, pairs in edits.items():
    f = pathlib.Path(path)
    if not f.exists():
        continue
    t = f.read_text()
    for a, b in pairs:
        t = t.replace(a, b)
    f.write_text(t)
print("responsive padding applied")
PY

# ---- outer shell: no rounded card on phones ----
python3 - << 'PY'
p = "src/App.tsx"
s = open(p).read()
s = s.replace(
  'className="min-h-screen bg-[#171717] lg:p-3"',
  'className="min-h-screen bg-[#171717] lg:p-3"'
)
s = s.replace(
  'className="flex-1 min-w-0 bg-[#1A1A1A] lg:rounded-3xl lg:border lg:border-[#2A2A2A] overflow-hidden"',
  'className="flex-1 min-w-0 bg-[#1A1A1A] lg:rounded-3xl lg:border lg:border-[#2A2A2A] lg:overflow-hidden"'
)
open(p, "w").write(s)
print("shell adapts")
PY

echo "responsive done"
