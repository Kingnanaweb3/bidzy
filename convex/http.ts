import { httpRouter } from "convex/server";
import { httpAction } from "./_generated/server";
import { internal, components } from "./_generated/api";
import { registerStaticRoutes } from "@convex-dev/static-hosting";

const http = httpRouter();

http.route({
  path: "/agentmail/webhook",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    let payload;
    try {
      payload = await request.json();
    } catch {
      return new Response("bad json", { status: 400 });
    }

    const type = payload.event_type ?? payload.type;
    if (type && type !== "message.received") {
      return new Response("ignored", { status: 200 });
    }

    const m = payload.message ?? payload.data ?? payload;
    const from =
      m.from_address ?? m.from ?? m.sender ?? m.envelope_from ?? "";
    const to = Array.isArray(m.to) ? m.to[0] : m.to ?? m.to_address ?? "";
    const text =
      m.extracted_text ?? m.text ?? m.plain_text ?? m.body ?? m.snippet ?? "";

    const fromEmail = String(from).match(/<([^>]+)>/)?.[1] ?? String(from);

    await ctx.runMutation(internal.mail.handleInbound, {
      fromAddress: fromEmail,
      toAddress: String(to),
      subject: m.subject,
      text: String(text),
      messageId: m.message_id ?? m.id,
      threadId: m.thread_id,
      attachments: (m.attachments ?? []).map((a) => ({
        filename: a.filename ?? a.name ?? "attachment",
        url: a.url ?? a.download_url ?? "",
        contentType: a.content_type ?? a.contentType,
      })),
    });

    return new Response("ok", { status: 200 });
  }),
});

// quick health check
http.route({
  path: "/agentmail/webhook",
  method: "GET",
  handler: httpAction(async () => new Response("bidzy webhook alive")),
});

// The product lives at /app; the landing page is the root. Both are real
// files, so the clean URL has to be mapped to one of them explicitly.
http.route({
  path: "/app",
  method: "GET",
  handler: httpAction(async () =>
    Response.redirect("/app/index.html", 302)
  ),
});

// Serve the built frontend. Registered last so the routes above win
// before the SPA fallback matches everything.
registerStaticRoutes(http, components.staticHosting, { spaFallback: true });

export default http;
