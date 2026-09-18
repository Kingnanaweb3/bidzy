import { cronJobs } from "convex/server";
import { internal } from "./_generated/api";

const crons = cronJobs();

// Waiting is only useful if something brings the job back. Nobody has to
// remember to press anything.
crons.daily(
  "chase companies who haven't priced yet",
  { hourUTC: 9, minuteUTC: 0 },
  internal.chase.run
);

export default crons;
