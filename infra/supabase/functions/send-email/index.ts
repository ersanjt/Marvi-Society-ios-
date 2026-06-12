import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

type Locale = "en" | "tr";
type Template = "welcome_application" | "membership_approved";

type OutboxRow = {
  id: string;
  to_email: string;
  template: Template;
  locale: string;
  variables: Record<string, string>;
  status: string;
};

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const FROM_EMAIL = Deno.env.get("MARVI_FROM_EMAIL") ?? "Marvi Society <hello@marvisociety.com>";
const REPLY_TO = Deno.env.get("MARVI_REPLY_TO") ?? "support@marvisociety.com";

function localeOf(raw: string): Locale {
  return raw?.toLowerCase().startsWith("tr") ? "tr" : "en";
}

function buildEmail(template: Template, locale: Locale, vars: Record<string, string>) {
  const name = vars.name ?? "Creator";
  const site = vars.site_url ?? "https://marvisociety.com";

  const wrap = (title: string, body: string) => `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;background:#0a0a0c;font-family:-apple-system,BinkMacSystemFont,'Segoe UI',sans-serif;color:#f5f5f7;padding:32px 16px;">
  <table width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;margin:0 auto;background:#141418;border-radius:16px;border:1px solid #2a2a32;">
    <tr><td style="padding:28px 28px 8px;">
      <p style="margin:0;font-size:12px;letter-spacing:0.12em;text-transform:uppercase;color:#ff2f77;font-weight:700;">Marvi Society</p>
      <h1 style="margin:12px 0 0;font-size:24px;line-height:1.3;color:#ffffff;">${title}</h1>
    </td></tr>
    <tr><td style="padding:8px 28px 20px;font-size:15px;line-height:1.6;color:#c8c8d0;">${body}</td></tr>
    <tr><td style="padding:0 28px 28px;">
      <a href="${site}" style="display:inline-block;background:linear-gradient(135deg,#ff2f77,#ff6b35);color:#fff;text-decoration:none;font-weight:700;padding:12px 20px;border-radius:10px;">marvisociety.com</a>
    </td></tr>
    <tr><td style="padding:16px 28px 24px;border-top:1px solid #2a2a32;font-size:12px;color:#888892;">
      ${locale === "tr" ? "Sorularınız için" : "Questions?"} <a href="mailto:support@marvisociety.com" style="color:#ff2f77;">support@marvisociety.com</a>
    </td></tr>
  </table>
</body>
</html>`;

  if (template === "welcome_application") {
    if (locale === "tr") {
      return {
        subject: "Marvi Society — başvurunuz alındı",
        html: wrap(
          `Merhaba ${name},`,
          `<p>Başvurunuz bize ulaştı. Ekibimiz profilinizi inceleyecek ve onaylandığında size e-posta göndereceğiz.</p>
           <p>Şehir: <strong>${vars.city ?? "İstanbul"}</strong></p>
           <p>Bu arada <a href="${site}/creators" style="color:#ff2f77;">marvisociety.com</a> üzerinden topluluğumuzu keşfedebilirsiniz.</p>`
        ),
      };
    }
    return {
      subject: "Marvi Society — your application was received",
      html: wrap(
        `Hi ${name},`,
        `<p>We received your creator application. Our team will review your profile and email you once you are approved.</p>
         <p>City: <strong>${vars.city ?? "Istanbul"}</strong></p>
         <p>In the meantime, explore our community at <a href="${site}/creators" style="color:#ff2f77;">marvisociety.com</a>.</p>`
      ),
    };
  }

  if (locale === "tr") {
    return {
      subject: "Marvi Society — kaydınız onaylandı",
      html: wrap(
        `Tebrikler ${name}!`,
        `<p><strong>Kaydınız onaylandı.</strong> Artık Marvi Society creator üyesisiniz.</p>
         <p>İstanbul'daki seçilmiş venue davetlerini keşfetmek için uygulamayı açın ve Explore sekmesine gidin.</p>
         <p>İyi iş birlikleri dileriz.</p>`
      ),
    };
  }

  return {
    subject: "Marvi Society — your registration is approved",
    html: wrap(
      `Congratulations ${name}!`,
      `<p><strong>Your registration has been accepted.</strong> You are now an approved Marvi Society creator.</p>
       <p>Open the app and head to Explore to discover curated venue invitations in Istanbul.</p>
       <p>Welcome to the club.</p>`
    ),
  };
}

async function sendWithResend(to: string, subject: string, html: string) {
  if (!RESEND_API_KEY) {
    throw new Error("RESEND_API_KEY is not configured on the Edge Function");
  }

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: FROM_EMAIL,
      to: [to],
      reply_to: REPLY_TO,
      subject,
      html,
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Resend error ${response.status}: ${text}`);
  }

  return response.json();
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  );

  const body = await req.json();
  const outboxId = body.outbox_id as string | undefined;

  if (!outboxId) {
    return Response.json({ error: "outbox_id required" }, { status: 400 });
  }

  const { data: row, error: fetchError } = await supabase
    .from("email_outbox")
    .select("id, to_email, template, locale, variables, status")
    .eq("id", outboxId)
    .single();

  if (fetchError || !row) {
    return Response.json({ error: fetchError?.message ?? "Outbox row not found" }, { status: 404 });
  }

  const outbox = row as OutboxRow;
  if (outbox.status === "sent") {
    return Response.json({ ok: true, skipped: true });
  }

  try {
    const locale = localeOf(outbox.locale);
    const template = outbox.template as Template;
    const { subject, html } = buildEmail(template, locale, outbox.variables ?? {});

    await sendWithResend(outbox.to_email, subject, html);

    await supabase
      .from("email_outbox")
      .update({ status: "sent", sent_at: new Date().toISOString(), error_message: null })
      .eq("id", outboxId);

    return Response.json({ ok: true, template, locale, to: outbox.to_email });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    await supabase
      .from("email_outbox")
      .update({ status: "failed", error_message: message })
      .eq("id", outboxId);

    return Response.json({ error: message }, { status: 500 });
  }
});
