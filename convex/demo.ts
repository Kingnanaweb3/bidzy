import { mutation } from "./_generated/server";
import { components } from "./_generated/api";

// Puts the project back to "we've asked, nobody has replied yet" so the
// email loop can be shown from the beginning. Keeps the inbox.
export const awaitingReplies = mutation({
  args: {},
  handler: async (ctx) => {
    const jobs = await ctx.db.query("jobs").collect();
    for (const job of jobs) {
      await ctx.runMutation(components.quoteEngine.quotes.clearJob, {
        jobKey: String(job._id),
      });
    }
    const invs = await ctx.db.query("invitations").collect();
    for (const i of invs) {
      await ctx.db.patch(i._id, { status: "sent", chaseCount: 0 });
    }
    const msgs = await ctx.db.query("messages").collect();
    for (const m of msgs) await ctx.db.delete(m._id);
    return { reset: invs.length };
  },
});
