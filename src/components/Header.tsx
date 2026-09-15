import { useMutation } from "convex/react";
import { api } from "../../convex/_generated/api";

export default function Header({ project }) {
  const bump = useMutation(api.projects.bumpRevision);

  return (
    <header className="border-b border-stone-200 bg-white">
      <div className="mx-auto max-w-[1400px] px-6 py-4 flex items-center justify-between">
        <div className="flex items-baseline gap-4">
          <span className="text-xl font-bold tracking-tight">Bidzy</span>
          <span className="text-stone-300">/</span>
          <span className="text-sm text-stone-600">{project.name}</span>
          <span className="text-[11px] uppercase tracking-wide text-stone-400 border border-stone-200 rounded px-1.5 py-0.5">
            Design rev {project.revision}
          </span>
        </div>
        <button
          onClick={() =>
            bump({
              projectId: project._id,
              note: "Architect issued a design update - glazing spec changed",
            })
          }
          className="text-xs font-medium bg-stone-900 text-white px-3 py-2 rounded-md hover:bg-stone-700 transition"
        >
          Simulate design change
        </button>
      </div>
    </header>
  );
}
