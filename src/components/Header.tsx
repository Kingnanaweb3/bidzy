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
