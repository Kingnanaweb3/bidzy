import { httpRouter } from "convex/server";
import { httpAction } from "./_generated/server";
import { internal } from "./_generated/api";

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

export default http;
