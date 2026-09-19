import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, Chip, Dot, IconBox, I, money } from "./ui";

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
        tone="good"
        accent
      />
      <Stat
        icon={I.alert}
        label="Cheapest on paper"
        value={money(d.headlineLowest)}
        dim
        tone={d.headlineMisleads ? "warn" : "neutral"}
        foot={d.headlineParty ?? "waiting on prices"}
        chip={
          d.headlineMisleads && gap != null ? (
            <Chip tone="warn">really {money(Math.abs(gap))} more</Chip>
          ) : null
        }
      />
      <Stat
        icon={I.mail}
        tone={d.staleCount > 0 ? "warn" : "info"}
        label="Replies"
        value={
          <>
            {d.quotedCount}
            <span className="text-[#6E6C66]">/{d.invitedCount}</span>
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

function Stat({ icon, label, value, foot, chip, accent, dim, tone }) {
  return (
    <Card className="p-5 sm:p-6 flex flex-col">
      <div className="h-9 flex items-center gap-3 mb-5">
        <IconBox>{icon}</IconBox>
        <span className="text-[length:var(--step--1)] sm:text-[length:var(--step-0)] font-semibold">{label}</span>
        {tone && <span className="ml-auto"><Dot tone={tone} /></span>}
      </div>
      <p
        className={`num text-[length:var(--step-5)] font-semibold leading-9 ${
          accent ? "text-[#4ADE80]" : dim ? "text-[#B5B3AA]" : "text-[#FBFBF7]"
        }`}
      >
        {value}
      </p>
      <div className="mt-3 space-y-2">
        <div className="h-[18px] text-[length:var(--step--2)] sm:text-[length:var(--step--1)] text-[#B5B3AA] truncate">
          {foot}
        </div>
        <div className="h-[22px] flex items-center">{chip}</div>
      </div>
    </Card>
  );
}
