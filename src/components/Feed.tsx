import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, CardHead, Empty, I, when } from "./ui";

const DOT = {
  scope_changed: "bg-[#FBBF24]",
  quote_stale: "bg-[#FBBF24]",
  quote_valid: "bg-[#4ADE80]",
  quote_parsed: "bg-[#4ADE80]",
  reply_received: "bg-[#60A5FA]",
  reprice_requested: "bg-[#60A5FA]",
  parse_failed: "bg-[#F87171]",
  chase_sent: "bg-[#60A5FA]",
  gave_up: "bg-[#F87171]",
  licence_flag: "bg-[#F87171]",
  licence_checked: "bg-[#4ADE80]",
};

export default function Feed({ projectId, limit = 30, full }) {
  const events = useQuery(api.events.feed, { projectId, limit });

  return (
    <Card className="h-fit">
      <CardHead icon={I.clock} title="Activity" />
      {events && events.length === 0 ? (
        <Empty>Nothing yet. Ask the companies for a price to begin.</Empty>
      ) : (
        <ol className={`px-4 sm:px-6 py-5 space-y-5 ${full ? "" : "max-h-[548px] overflow-y-auto"}`}>
          {events?.map((e) => (
            <li key={e._id} className="flex gap-3">
              <span
                className={`mt-[7px] h-1.5 w-1.5 rounded-full shrink-0 ${
                  DOT[e.type] ?? "bg-[#2E2E2B]"
                }`}
              />
              <div className="min-w-0">
                <p className="text-[length:var(--step--1)] sm:text-[length:var(--step--1)] text-[#D6D4CC] leading-5">{e.summary}</p>
                <p className="text-[length:var(--step--2)] text-[#6E6C66] mt-1 leading-4">
                  {when(e.createdAt)}
                </p>
              </div>
            </li>
          ))}
        </ol>
      )}
    </Card>
  );
}
