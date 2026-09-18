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
