import { I } from "./ui";
import { Wordmark } from "./Logo";

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
          flex flex-col py-6 px-4 bg-[#0C0C0C] lg:bg-transparent
          border-r border-[#242422] lg:border-0
          transition-transform duration-200
          ${open ? "translate-x-0" : "-translate-x-full"} lg:translate-x-0
        `}
      >
        <a href="/index.html" className="h-9 flex items-center px-2 mb-8 hover:opacity-80 transition">
          <Wordmark size={18} />
        </a>

        {NAV.map(([label, items]) => (
          <div key={label}>
            <p className="h-8 flex items-end text-[10px] font-semibold tracking-[0.12em] uppercase text-[#6E6C66] px-3 mt-4 mb-1">
              {label}
            </p>
            {items.map(([id, text, icon]) => (
              <button
                key={id}
                onClick={() => {
                  onNavigate(id);
                  onClose?.();
                }}
                className={`h-10 w-full flex items-center gap-3 px-3 rounded-xl text-[length:var(--step-0)] mb-0.5 text-left transition ${
                  page === id
                    ? "bg-[#1C1C1A] text-white font-medium"
                    : "text-[#B5B3AA] hover:text-[#FBFBF7] hover:bg-[#171715]"
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
          <div className="rounded-2xl bg-[#171715] border border-[#262624] p-4">
            <p className="text-[length:var(--step--1)] text-[#B5B3AA] leading-5">Companies reply to</p>
            <p className="text-[length:var(--step--1)] text-[#FBFBF7] break-all mt-1 leading-5">
              {job?.inboxAddress ?? "no inbox yet"}
            </p>
            <p className="text-[length:var(--step--2)] text-[#6E6C66] mt-2 leading-5">
              They never sign in. It's just email.
            </p>
          </div>
        </div>
      </aside>
    </>
  );
}
