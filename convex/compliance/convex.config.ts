import { defineComponent } from "convex/server";

// Whether a company is allowed to do the work. Separate from what their
// price means: a licence can lapse without a number changing, and a price
// can go stale without anything happening to the licence. Different
// reasons to change, so different components.
export default defineComponent("compliance");
