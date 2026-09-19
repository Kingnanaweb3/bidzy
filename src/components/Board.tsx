import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, CardHead, Chip, Action, Meta, ago, I, money } from "./ui";
import BoardMobile from "./BoardMobile";

export default function Board({ jobId }) {
  const d = useQuery(api.jobs.board, { jobId });
  if (!d)
    return (
      <Card>
        <CardHead icon={I.scale} title="Price comparison" note="loading" />
      </Card>
    );

  const {
    rows, allExclusions, lowest, lowestParty,
    headlineLowest, headlineParty, headlineMisleads,
    previousBest, lowestMoved, staleCount,
  } = d;

  const wide = rows.length > 4;
  const labelW = wide ? 16 : 22;
  const colW = `${Math.floor((100 - labelW) / Math.max(rows.length, 1))}%`;

  return (
    <Card>
      <CardHead
        icon={I.scale}
        title="Price comparison"
        note="Missing work is priced from what the others charged"
      />

      {(lowestMoved || headlineMisleads) && (
        <div className="mx-4 sm:mx-6 mt-5 sm:mt-6 rounded-xl bg-[#2E2410] border border-[#443415] px-4 py-3.5">
          <p className="text-[length:var(--step--1)] sm:text-[length:var(--step-0)] text-[#FBBF24] leading-5 sm:leading-6">
            {lowestMoved ? (
              <>
                You changed the job, so {staleCount} price
                {staleCount === 1 ? "" : "s"} no longer{" "}
                {staleCount === 1 ? "applies" : "apply"}. {lowestParty} already
                priced this and still stands at {money(lowest)}, up from{" "}
                {money(previousBest)}.
              </>
            ) : (
              <>
                {headlineParty} looks cheapest at {money(headlineLowest)} — but
                once the work they leave out is priced in, {lowestParty} is the
                cheaper job at {money(lowest)}.
              </>
            )}
          </p>
        </div>
      )}

      <div>
        <BoardMobile d={d} />
      </div>
    </Card>
  );
}

function Line({ label, note, children }) {
  return (
    <tr className="border-t border-[#1C1C1A]">
      <td className="py-4 pr-5 align-top">
        <div className="text-[length:var(--step-0)] text-[#FBFBF7] leading-6">{label}</div>
        <div className="text-[length:var(--step--2)] text-[#6E6C66] leading-4 mt-0.5">{note}</div>
      </td>
      {children}
    </tr>
  );
}

function Status({ row }) {
  if (row.status === "declined") return <Chip tone="neutral">not bidding</Chip>;
  if (row.quote?.stale) return <Chip tone="warn">needs repricing</Chip>;
  if (row.quote) return <Chip tone="good">replied</Chip>;
  if (row.chaseCount > 0) return <Chip tone="neutral">chased {row.chaseCount}×</Chip>;
  return <Chip tone="neutral">no reply yet</Chip>;
}

// A company that isn't bidding shouldn't look like one we're still waiting on.
function Blank({ row }) {
  return (
    <span className="text-[length:var(--step--1)] text-[#55534E]">
      {row.status === "declined" ? "not bidding" : "—"}
    </span>
  );
}
