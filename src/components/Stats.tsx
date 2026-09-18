import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, Chip, IconBox, I } from "./ui";

const money = (n) =>
  n == null ? "—" : "$" + n.toLocaleString(undefined, { maximumFractionDigits: 0 });

export default function Stats({ jobId }) {
  const d = useQuery(api.jobs.board, { jobId });
  if (!d) return null;

  const gap =
    d.lowest != null && d.headlineLowest != null
      ? d.lowest - d.headlineLowest
      : null;

  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
      <Card className="p-5">
        <div className="flex items-center gap-3 mb-4">
          <IconBox>{I.scale}</IconBox>
          <span className="text-[13.5px] font-semibold">Best real cost</span>
        </div>
        <p className="num text-[30px] font-bold tracking-tight">
          {money(d.lowest)}
        </p>
        <p className="text-[12.5px] text-[#A1A1A1] mt-2">
          {d.lowestParty ?? "no valid price yet"}
        </p>
      </Card>

      <Card className="p-5">
        <div className="flex items-center gap-3 mb-4">
          <IconBox>{I.alert}</IconBox>
          <span className="text-[13.5px] font-semibold">Cheapest on paper</span>
        </div>
        <p className="num text-[30px] font-bold tracking-tight text-[#A1A1A1]">
          {money(d.headlineLowest)}
        </p>
        <div className="flex items-center gap-2 mt-2">
          {d.headlineMisleads ? (
            <>
              <Chip tone="warn">
                really {gap > 0 ? "+" : ""}
                {money(Math.abs(gap))} more
              </Chip>
              <span className="text-[12.5px] text-[#A1A1A1]">
                {d.headlineParty}
              </span>
            </>
          ) : (
            <span className="text-[12.5px] text-[#A1A1A1]">
              {d.headlineParty ?? "waiting on prices"}
            </span>
          )}
        </div>
      </Card>

      <Card className="p-5">
        <div className="flex items-center gap-3 mb-4">
          <IconBox>{I.mail}</IconBox>
          <span className="text-[13.5px] font-semibold">Replies</span>
        </div>
        <p className="num text-[30px] font-bold tracking-tight">
          {d.quotedCount}
          <span className="text-[#5A5A5A]">/{d.invitedCount}</span>
        </p>
        <div className="flex items-center gap-2 mt-2">
          {d.staleCount > 0 ? (
            <Chip tone="warn">{d.staleCount} need repricing</Chip>
          ) : (
            <Chip tone="good">all current</Chip>
          )}
        </div>
      </Card>
    </div>
  );
}
