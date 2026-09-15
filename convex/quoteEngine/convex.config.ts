import { defineComponent } from "convex/server";

// Quote intelligence. Owns everything about what a price actually means:
// normalisation, what it leaves out, comparable cost, and whether it is
// still valid for the job as it now stands.
//
// Tables here are isolated. Nothing in the host app can read or write them
// except through the functions this component exports.
export default defineComponent("quoteEngine");
