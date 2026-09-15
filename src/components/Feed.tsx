import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";

const DOT = {
  design_changed: "bg-amber-500",
  quote_parsed: "bg-emerald-500",
  invite_sent: "bg-stone-400",
  reply_received: "bg-blue-500",
  licence_flag: "bg-red-500",
};

export default function Feed({ projectId }) {
  const events = useQuery(api.events.feed, { projectId, limit: 25 });

  return (
    <aside>
      <h2 className="text-[11px] uppercase tracking-widest text-stone-400 mb-4">
        Activity
      </h2>
      <div className="space-y-3">
        {events?.map((e) => (
          <div key={e._id} className="flex gap-3 text-sm">
            <span
              className={`mt-1.5 h-1.5 w-1.5 rounded-full shrink-0 ${
                DOT[e.type] ?? "bg-stone-300"
              }`}
            />
            <div>
              <p className="text-stone-700 leading-snug">{e.summary}</p>
              <p className="text-[11px] text-stone-400 mt-0.5">
                {new Date(e.createdAt).toLocaleString(undefined, {
                  month: "short",
                  day: "numeric",
                  hour: "numeric",
                  minute: "2-digit",
                })}
              </p>
            </div>
          </div>
        ))}
        {events && events.length === 0 && (
          <p className="text-sm text-stone-400">Nothing yet.</p>
        )}
      </div>
    </aside>
  );
}
