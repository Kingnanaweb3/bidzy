import { mutation } from "./_generated/server";
import { components } from "./_generated/api";

// Re-writes existing quotes through the component so older rows pick up
// canonical exclusion labels.
export const labels = mutation({
  args: {},
  handler: async (ctx) => {
    const jobs = await ctx.db.query("jobs").collect();
    let touched = 0;
    for (const job of jobs) {
      const quotes = await ctx.runQuery(
        components.quoteEngine.quotes.listByJob,
        { jobKey: String(job._id) }
      );
      for (const q of quotes) {
        await ctx.runMutation(components.quoteEngine.quotes.record, {
          jobKey: String(job._id),
          partyKey: q.partyKey,
          partyName: q.partyName,
          total: q.total,
          lineItems: q.lineItems,
          inclusions: q.inclusions,
          exclusions: q.exclusions,
          scopeTags: q.scopeTags,
          needsReview: q.needsReview,
          rawText: q.rawText,
          sourceUrl: q.sourceUrl,
        });
        touched++;
      }
    }
    return { touched };
  },
});
