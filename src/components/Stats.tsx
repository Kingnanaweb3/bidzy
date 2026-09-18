import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, Chip, IconBox, I, money } from "./ui";

export default function Stats({ jobId }) {
  const d = useQuery(api.jobs.board, { jobId });
  if (!d) return <div className="h-[148px]" />;

  const gap =
    d.lowest != null && d.headlineLowest != null ? d.lowest - d.headlineLowest : null;

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-5 sm:gap-6">
      <Stat
        icon={I.scale}
        label="Best real cost"
        value={money(d.lowest)}
        foot={d.lowestParty ?? "no valid price yet"}
        accent
      />
      <Stat
        icon={I.alert}
        label="Cheapest on paper"
        value={money(d.headlineLowest)}
        dim
        foot={d.headlineParty ?? "waiting on prices"}
        chip={
          d.headlineMisleads && gap != null ? (
            <Chip tone="warn">really {money(Math.abs(gap))} more</Chip>
          ) : null
        }
      />
      <Stat
        icon={I.mail}
        label="Replies"
        value={
          <>
            {d.quotedCount}
            <span className="text-[#5A5A5A]">/{d.invitedCount}</span>
          </>
        }
        foot={
          d.invitedCount - d.quotedCount > 0
            ? `${d.invitedCount - d.quotedCount} still out`
            : "everyone has answered"
        }
        chip={
          d.staleCount > 0 ? (
            <Chip tone="warn">{d.staleCount} need repricing</Chip>
          ) : (
            <Chip tone="good">all current</Chip>
          )
        }
      />
    </div>
  );
}

function Stat({ icon, label, value, foot, chip, accent, dim }) {
  return (
    <Card className="p-5 sm:p-6 flex flex-col">
      <div className="h-9 flex items-center gap-3 mb-5">
        <IconBox>{icon}</IconBox>
        <span className="text-[12.5px] sm:text-[13.5px] font-semibold">{label}</span>
      </div>
      <p
        className={`num text-[30px] font-bold tracking-tight leading-9 ${
          accent ? "text-[#4ADE80]" : dim ? "text-[#A1A1A1]" : "text-[#EDEDED]"
        }`}
      >
        {value}
      </p>
      <div className="mt-3 space-y-2">
        <div className="h-[18px] text-[11.5px] sm:text-[12.5px] text-[#A1A1A1] truncate">
          {foot}
        </div>
        <div className="h-[22px] flex items-center">{chip}</div>
      </div>
    </Card>
  );
}
