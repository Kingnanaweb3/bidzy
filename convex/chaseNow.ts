import { action } from "./_generated/server";
import { internal } from "./_generated/api";

// Same code path the daily schedule uses. Here so it can be demonstrated
// without waiting until tomorrow morning.
export const run = action({
  args: {},
  handler: async (ctx) => ctx.runAction(internal.chase.run, {}),
});
