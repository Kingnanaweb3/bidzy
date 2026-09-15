import { useMutation, useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { useState } from "react";

export default function Header({ project }) {
  const change = useMutation(api.projects.changeScope);
  const reset = useMutation(api.projects.resetStale);
  const addenda = useQuery(api.projects.addenda, { projectId: project._id });
  const [busy, setBusy] = useState(false);

  const changed = (addenda?.length ?? 0) > 0;

  return (
    <header className="border-b border-stone-200 bg-white sticky top-0 z-10">
      <div className="mx-auto max-w-[1400px] px-6 py-4 flex items-center justify-between">
        <div className="flex items-baseline gap-4 min-w-0">
          <span className="text-xl font-bold tracking-tight">Bidzy</span>
          <span className="text-stone-300">/</span>
          <span className="text-sm text-stone-600 truncate">
            {project.name} - {project.client}
          </span>
        </div>

        <div className="flex items-center gap-3">
          <span className="text-[11px] text-stone-500 hidden md:inline">
            {project.scopeNote}
          </span>
          {changed && (
            <button
              onClick={async () => {
                setBusy(true);
                await reset({ projectId: project._id });
                setBusy(false);
              }}
              disabled={busy}
              className="text-xs font-medium text-stone-500 hover:text-stone-900 px-3 py-2 transition disabled:opacity-40"
            >
              Undo
            </button>
          )}
          <button
            onClick={async () => {
              setBusy(true);
              await change({ projectId: project._id });
              setBusy(false);
            }}
            disabled={busy || changed}
            className="text-xs font-medium bg-stone-900 text-white px-3 py-2 rounded-md hover:bg-stone-700 transition disabled:bg-stone-200 disabled:text-stone-400"
          >
            {changed ? "Job changed" : "Change to slate instead"}
          </button>
        </div>
      </div>
    </header>
  );
}
