import { mutation } from "./_generated/server";

export const real = mutation({
  args: {},
  handler: async (ctx) => {
    const map = {
      "Apex Roofing": "APEX CONTRACTING & RENOVATIONS INC",
      "Skyline Exteriors": "NYC SKYLINE CONSTRUCTION CORP",
      "Crown Roof Systems": "CITI SKYLINE INTERIORS INC",
    };
    const firms = await ctx.db.query("firms").collect();
    let n = 0;
    for (const f of firms) {
      if (map[f.name]) {
        await ctx.db.patch(f._id, { name: map[f.name] });
        n++;
      }
    }
    return { renamed: n };
  },
});
