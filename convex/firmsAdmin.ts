import { mutation } from "./_generated/server";
import { v } from "convex/values";

// Point the seeded firms at addresses you actually control.
export const setEmails = mutation({
  args: { pairs: v.array(v.object({ name: v.string(), email: v.string() })) },
  handler: async (ctx, { pairs }) => {
    const firms = await ctx.db.query("firms").collect();
    let updated = 0;
    for (const p of pairs) {
      const f = firms.find((x) =>
        x.name.toLowerCase().startsWith(p.name.toLowerCase())
      );
      if (f) {
        await ctx.db.patch(f._id, { email: p.email.toLowerCase() });
        updated++;
      }
    }
    return { updated };
  },
});
