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
