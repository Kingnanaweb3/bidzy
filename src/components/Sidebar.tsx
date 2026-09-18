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
          <span className="display text-[17px] font-bold tracking-tight">Bidzy</span>
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
