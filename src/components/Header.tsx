import { useMutation, useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { useState } from "react";
import { I, Primary, Ghost, Eyebrow } from "./ui";

export default function Header({ project, title, note, showScopeAction, onMenu }) {
  const change = useMutation(api.projects.changeScope);
  const reset = useMutation(api.projects.resetStale);
  const addenda = useQuery(api.projects.addenda, { projectId: project._id });
  const [busy, setBusy] = useState(false);
  const changed = (addenda?.length ?? 0) > 0;

  return (
    <div className="px-4 sm:px-6 pt-5 sm:pt-6 pb-5 sm:pb-6 border-b border-[#242422]">
      <div className="h-10 flex items-center gap-3 mb-6 sm:mb-7">
        <button
          onClick={onMenu}
          aria-label="Open menu"
          className="lg:hidden h-10 w-10 shrink-0 rounded-xl bg-[#171715] border border-[#262624] grid place-items-center text-[#B5B3AA]"
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
            <path d="M4 7h16M4 12h16M4 17h16" />
          </svg>
        </button>
        <div className="hidden sm:flex h-10 items-center gap-2.5 bg-[#171715] border border-[#262624] rounded-xl px-3.5 w-full max-w-[360px] text-[#6E6C66]">
          {I.search}
          <span className="text-[length:var(--step-0)] truncate">Search companies, prices, email</span>
        </div>
        <div className="ml-auto flex items-center gap-2.5">
          <div className="hidden xl:flex h-10 items-center gap-2 bg-[#171715] border border-[#262624] rounded-xl px-3.5 text-[length:var(--step--1)] text-[#B5B3AA]">
            {I.home}
            <span className="truncate max-w-[280px]">{project.scopeNote}</span>
          </div>
          <div className="h-10 w-10 rounded-full bg-[#242422] grid place-items-center text-[length:var(--step--1)] font-semibold text-[#B5B3AA] shrink-0">
            H
          </div>
        </div>
      </div>

      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <Eyebrow>{project.scopeNote}</Eyebrow>
          <h1 className="display text-[21px] sm:text-[25px] font-semibold leading-7 sm:leading-8">{title}</h1>
          <p className="text-[length:var(--step-0)] sm:text-[length:var(--step-0)] text-[#B5B3AA] mt-1.5 leading-5">
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
