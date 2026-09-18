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
    <div className="pt-6 grid grid-cols-1 xl:grid-cols-[minmax(0,1fr)_360px] gap-6">
      <Card>
        <CardHead
          icon={I.wallet}
          title="If you go with the best price"
          note={winner ? winner.firmName : "no valid price yet"}
        />
        {!winner ? (
          <Empty>No valid price to budget against yet.</Empty>
        ) : (
          <div className="p-6">
            <p className="num text-[38px] font-bold tracking-tight leading-none text-[#4ADE80]">
              {money(winner.quote.comparable)}
            </p>
            <p className="text-[12.5px] text-[#A1A1A1] mt-3 leading-5">
              Quoted {money(winner.quote.total)}
              {winner.quote.hidden > 0 &&
                `, plus ${money(winner.quote.hidden)} of work they left out`}
              .
            </p>

            <div className="mt-7 divide-y divide-[#242424] border-t border-[#242424]">
              {winner.quote.lineItems.map((li, i) => (
                <div key={i} className="h-11 flex items-center justify-between gap-4">
                  <span className="text-[13px] text-[#A1A1A1] truncate">{li.label}</span>
                  <span className="num text-[13px] text-[#C9C9C9] shrink-0">
                    {money(li.amount)}
                  </span>
                </div>
              ))}
              {winner.quote.hidden > 0 && (
                <div className="h-11 flex items-center justify-between gap-4">
                  <span className="text-[13px] text-[#FBBF24] truncate">
                    Work not covered, priced from the others
                  </span>
                  <span className="num text-[13px] text-[#FBBF24] shrink-0">
                    {money(winner.quote.hidden)}
                  </span>
                </div>
              )}
              <div className="h-14 flex items-center justify-between gap-4">
                <span className="text-[13.5px] font-semibold">Total to budget</span>
                <span className="num text-[16px] font-bold">
                  {money(winner.quote.comparable)}
                </span>
              </div>
            </div>
          </div>
        )}
      </Card>

      <Card className="h-fit">
        <CardHead icon={I.alert} title="What picking wrong would cost" />
        <div className="p-6 space-y-5">
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
            <p className="text-[12.5px] text-[#A1A1A1] leading-5 pt-2 border-t border-[#242424]">
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

function Row({ label, value, tone = "text-[#EDEDED]" }) {
  return (
    <div className="flex items-center justify-between gap-4">
      <span className="text-[13px] text-[#A1A1A1]">{label}</span>
      <span className={`num text-[15px] font-semibold ${tone}`}>{value}</span>
    </div>
  );
}
