import { mutation } from "./_generated/server";

// One-off: empties the app-level quotes table so the table can be
// removed from the app schema and owned by the quoteEngine component.
export const clearQuotes = mutation({
  args: {},
  handler: async (ctx) => {
    const rows = await ctx.db.query("quotes").collect();
    for (const r of rows) await ctx.db.delete(r._id);
    return { deleted: rows.length };
  },
});
