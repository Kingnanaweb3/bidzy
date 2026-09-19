import { defineApp } from "convex/server";
import staticHosting from "@convex-dev/static-hosting/convex.config";
import quoteEngine from "./quoteEngine/convex.config";
import compliance from "./compliance/convex.config";

const app = defineApp();

// Serves the built frontend from this same deployment.
app.use(staticHosting);

// Owns quote normalisation, comparable cost and validity. Its tables are
// unreachable from the rest of the app - the only way in is its API.
app.use(quoteEngine);

// Owns whether a company is allowed to do the work, and the evidence for
// saying so. Nothing else can write to it.
app.use(compliance);

export default app;
