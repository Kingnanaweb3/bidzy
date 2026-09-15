import { useMutation, useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { useState } from "react";

export default function Header({ project }) {
  const publish = useMutation(api.projects.publishAddendum);
  const reset = useMutation(api.projects.resetStale);
  const addenda = useQuery(api.projects.addenda, { projectId: project._id });
  const [busy, setBusy] = useState(false);

  const published = (addenda?.length ?? 0) > 0;

  return (
    <header className="border-b border-stone-200 bg-white sticky top-0 z-10">
      <div className="mx-auto max-w-[1400px] px-6 py-4 flex items-center justify-between">
        <div className="flex items-baseline gap-4">
          <span className="text-xl font-bold tracking-tight">Bidzy</span>
          <span className="text-stone-300">/</span>
          <span className="text-sm text-stone-600">{project.name}</span>
          <span className="text-[11px] uppercase tracking-wide text-stone-400 border border-stone-200 rounded px-1.5 py-0.5">
            Design rev {project.revision}
          </span>
        </div>

        <div className="flex items-center gap-2">
          {published && (
            <button
              onClick={async () => {
                setBusy(true);
                await reset({ projectId: project._id });
                setBusy(false);
              }}
              disabled={busy}
              className="text-xs font-medium text-stone-500 hover:text-stone-900 px-3 py-2 transition disabled:opacity-40"
            >
              Reset demo
            </button>
          )}
          <button
            onClick={async () => {
              setBusy(true);
              await publish({ projectId: project._id });
              setBusy(false);
            }}
            disabled={busy || published}
            className="text-xs font-medium bg-stone-900 text-white px-3 py-2 rounded-md hover:bg-stone-700 transition disabled:bg-stone-200 disabled:text-stone-400"
          >
            {published ? "Addendum published" : "Publish design change"}
          </button>
        </div>
      </div>
    </header>
  );
}
