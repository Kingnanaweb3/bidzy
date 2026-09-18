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
