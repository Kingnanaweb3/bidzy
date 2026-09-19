import { useQuery } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Card, CardHead, Chip, Empty, I, money } from "../components/ui";

export default function BudgetPage({ jobId }) {
  const d = useQuery(api.jobs.board, { jobId });
  if (!d) return <div className="pt-6" />;

  const winner = d.rows.find(
    (r) => r.quote?.comparable === d.lowest && !r.quote?.stale
  );
  const spread = d.rows
    .filter((r) => r.quote?.comparable != null && !r.quote.stale)
    .map((r) => r.quote.comparable);
  const worst = spread.length ? Math.max(...spread) : null;

  return (
    <div className="pt-5 sm:pt-6 grid grid-cols-1 xl:grid-cols-[minmax(0,1fr)_360px] gap-5 sm:gap-6">
      <Card>
        <CardHead
          icon={I.wallet}
          title="If you go with the best price"
          note={winner ? winner.firmName : "no valid price yet"}
        />
        {!winner ? (
          <Empty>No valid price to budget against yet.</Empty>
        ) : (
          <div className="p-4 sm:p-6">
            <p className="num text-[length:var(--step-5)] sm:text-[length:var(--step-5)] font-semibold leading-none text-[#4ADE80]">
              {money(winner.quote.comparable)}
            </p>
            <p className="text-[length:var(--step--1)] text-[#B5B3AA] mt-3 leading-5">
              Quoted {money(winner.quote.total)}
              {winner.quote.hidden > 0 &&
                `, plus ${money(winner.quote.hidden)} of work they left out`}
              .
            </p>

            <div className="mt-7 divide-y divide-[#1C1C1A] border-t border-[#1C1C1A]">
              {winner.quote.lineItems.map((li, i) => (
                <div key={i} className="h-11 flex items-center justify-between gap-4">
                  <span className="text-[length:var(--step--1)] sm:text-[length:var(--step-0)] text-[#B5B3AA] truncate">{li.label}</span>
                  <span className="num text-[length:var(--step--1)] sm:text-[length:var(--step-0)] text-[#D6D4CC] shrink-0">
                    {money(li.amount)}
                  </span>
                </div>
              ))}
              {winner.quote.hidden > 0 && (
                <div className="h-11 flex items-center justify-between gap-4">
                  <span className="text-[length:var(--step-0)] text-[#FBBF24] truncate">
                    Work not covered, priced from the others
                  </span>
                  <span className="num text-[length:var(--step-0)] text-[#FBBF24] shrink-0">
                    {money(winner.quote.hidden)}
                  </span>
                </div>
              )}
              <div className="h-14 flex items-center justify-between gap-4">
                <span className="display text-[length:var(--step-0)] font-semibold">Total to budget</span>
                <span className="num text-[length:var(--step-2)] font-bold">
                  {money(winner.quote.comparable)}
                </span>
              </div>
            </div>
          </div>
        )}
      </Card>

      <Card className="h-fit">
        <CardHead icon={I.alert} title="What picking wrong would cost" />
        <div className="p-4 sm:p-6 space-y-5">
          <Row
            label="Cheapest real cost"
            value={money(d.lowest)}
            tone="text-[#4ADE80]"
          />
          <Row label="Dearest real cost" value={money(worst)} />
          <Row
            label="Difference"
            value={
              worst != null && d.lowest != null ? money(worst - d.lowest) : "—"
            }
            tone="text-[#FBBF24]"
          />
          {d.headlineMisleads && (
            <p className="text-[length:var(--step--1)] text-[#B5B3AA] leading-5 pt-2 border-t border-[#1C1C1A]">
              Going by the headline price alone would have picked{" "}
              {d.headlineParty}, which is{" "}
              {money(Math.abs(d.lowest - d.headlineLowest))} more once the
              missing work is priced in.
            </p>
          )}
          {d.staleCount > 0 && (
            <div className="pt-2">
              <Chip tone="warn">
                {d.staleCount} price{d.staleCount === 1 ? "" : "s"} excluded, job changed
              </Chip>
            </div>
          )}
        </div>
      </Card>
    </div>
  );
}

function Row({ label, value, tone = "text-[#FBFBF7]" }) {
  return (
    <div className="flex items-center justify-between gap-4">
      <span className="text-[length:var(--step-0)] text-[#B5B3AA]">{label}</span>
      <span className={`num text-[length:var(--step-1)] font-semibold ${tone}`}>{value}</span>
    </div>
  );
}
