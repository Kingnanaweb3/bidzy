import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, IconBox, I } from "./ui";

const DOT = {
  scope_changed: "bg-[#FBBF24]",
  quote_stale: "bg-[#FBBF24]",
  quote_valid: "bg-[#4ADE80]",
  quote_parsed: "bg-[#4ADE80]",
  reply_received: "bg-[#60A5FA]",
  reprice_requested: "bg-[#60A5FA]",
  parse_failed: "bg-[#F87171]",
};

export default function Feed({ projectId }) {
  const events = useQuery(api.events.feed, { projectId, limit: 30 });

  return (
    <Card className="h-fit">
      <div className="flex items-center gap-3 px-5 py-4 border-b border-[#2A2A2A]">
        <IconBox>{I.clock}</IconBox>
        <h2 className="text-[14.5px] font-semibold">Activity</h2>
      </div>
      <ol className="px-5 py-4 space-y-4 max-h-[560px] overflow-y-auto">
        {events?.map((e) => (
          <li key={e._id} className="flex gap-3">
            <span
              className={`mt-1.5 h-1.5 w-1.5 rounded-full shrink-0 ${
                DOT[e.type] ?? "bg-[#3A3A3A]"
              }`}
            />
            <div className="min-w-0">
              <p className="text-[12.5px] text-[#C9C9C9] leading-snug">
                {e.summary}
              </p>
              <p className="text-[11px] text-[#5A5A5A] mt-1">
                {new Date(e.createdAt).toLocaleString(undefined, {
                  month: "short",
                  day: "numeric",
                  hour: "numeric",
                  minute: "2-digit",
                })}
              </p>
            </div>
          </li>
        ))}
        {events && events.length === 0 && (
          <li className="text-[12.5px] text-[#5A5A5A]">
            Nothing yet. Ask the companies for a price to begin.
          </li>
        )}
      </ol>
    </Card>
  );
}
