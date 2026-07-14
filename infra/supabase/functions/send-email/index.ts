import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

type Locale = "en" | "tr";
type Template =
  | "welcome_application"
  | "membership_approved"
  | "admin_message"
  | "invite_code"
  | "contact_form"
  | "demo_request";

type DeliveryMethod =
  | "resend"
  | "auth_invite"
  | "auth_magiclink"
  | "auth_notice";

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
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const EDGE_SECRET = Deno.env.get("MARVI_EDGE_SECRET") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SITE_URL = "https://marvisociety.com";

function localeOf(raw: string): Locale {
  return raw?.toLowerCase().startsWith("tr") ? "tr" : "en";
}

/** Escape user-supplied values before interpolating into HTML emails. */
function esc(value: string | undefined | null): string {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

/** Only the service role (DB webhook / pg_net dispatch / server) may invoke sends. */
function isAuthorized(req: Request): boolean {
  const auth = req.headers.get("Authorization") ?? "";
  const token = auth.replace(/^Bearer\s+/i, "").trim();
  if (!token) return false;
  if (SERVICE_ROLE_KEY && token === SERVICE_ROLE_KEY) return true;
  if (EDGE_SECRET && token === EDGE_SECRET) return true;
  return false;
}

function buildEmail(template: Template, locale: Locale, vars: Record<string, string>) {
  const name = esc(vars.name ?? "Creator");
  const site = esc(vars.site_url ?? SITE_URL);

  const wrap = (title: string, body: string) => `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;background:#0a0a0c;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#f5f5f7;padding:32px 16px;">
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
           <p>Şehir: <strong>${esc(vars.city ?? "İstanbul")}</strong></p>
           <p>Bu arada <a href="${site}/creators" style="color:#ff2f77;">marvisociety.com</a> üzerinden topluluğumuzu keşfedebilirsiniz.</p>`,
        ),
      };
    }
    return {
      subject: "Marvi Society — your application was received",
      html: wrap(
        `Hi ${name},`,
        `<p>We received your creator application. Our team will review your profile and email you once you are approved.</p>
         <p>City: <strong>${esc(vars.city ?? "Istanbul")}</strong></p>
         <p>In the meantime, explore our community at <a href="${site}/creators" style="color:#ff2f77;">marvisociety.com</a>.</p>`,
      ),
    };
  }

  if (template === "membership_approved") {
    if (locale === "tr") {
      return {
        subject: "Marvi Society — kaydınız onaylandı",
        html: wrap(
          `Tebrikler ${name}!`,
          `<p><strong>Kaydınız onaylandı.</strong> Artık Marvi Society creator üyesisiniz.</p>
           <p>İstanbul'daki seçilmiş venue davetlerini keşfetmek için uygulamayı açın ve Explore sekmesine gidin.</p>
           <p>İyi iş birlikleri dileriz.</p>`,
        ),
      };
    }
    return {
      subject: "Marvi Society — your registration is approved",
      html: wrap(
        `Congratulations ${name}!`,
        `<p><strong>Your registration has been accepted.</strong> You are now an approved Marvi Society creator.</p>
         <p>Open the app and head to Explore to discover curated venue invitations in Istanbul.</p>
         <p>Welcome to the club.</p>`,
      ),
    };
  }

  if (template === "admin_message") {
    const subject = vars.subject ?? "Marvi Society";
    const body = esc(vars.body ?? "").replace(/\n/g, "<br/>");
    const recipient = esc(vars.name ?? "Member");
    if (locale === "tr") {
      return { subject, html: wrap(`Merhaba ${recipient},`, `<p>${body}</p>`) };
    }
    return { subject, html: wrap(`Hi ${recipient},`, `<p>${body}</p>`) };
  }

  if (template === "invite_code") {
    const rawCode = vars.invite_code?.trim();
    if (!rawCode) {
      return {
        subject: "Marvi Society",
        html: wrap("Invite", "<p>Missing invite code.</p>"),
      };
    }
    const code = esc(rawCode);
    const deepLink = esc(vars.deep_link ?? `marvisociety://invite?code=${rawCode}`);
    if (locale === "tr") {
      return {
        subject: "Marvi Society — davet kodunuz",
        html: wrap(
          "Creator davetiniz",
          `<p>Marvi Society'ye katılmak için uygulamayı indirin, <strong>davet edilen e-posta adresinizle</strong> kayıt olun ve bu kodu girin:</p>
           <p style="font-size:22px;font-weight:700;letter-spacing:0.08em;color:#ff2f77;">${code}</p>
           <p><a href="${deepLink}" style="color:#ff2f77;">Uygulamada daveti aç</a> · <a href="${site}" style="color:#ff2f77;">marvisociety.com</a></p>`,
        ),
      };
    }
    return {
      subject: "Marvi Society — your invite code",
      html: wrap(
        "Your creator invite",
        `<p>Download the app, sign up with <strong>this email address</strong>, and enter this code:</p>
         <p style="font-size:22px;font-weight:700;letter-spacing:0.08em;color:#ff2f77;">${code}</p>
         <p><a href="${deepLink}" style="color:#ff2f77;">Open invite in app</a> · <a href="${site}" style="color:#ff2f77;">marvisociety.com</a></p>`,
      ),
    };
  }

  if (template === "contact_form") {
    const fromName = esc(vars.name ?? "Visitor");
    const fromEmail = esc(vars.email ?? REPLY_TO);
    const subjectLine = vars.subject ?? "Support request";
    const body = esc(vars.message ?? "").replace(/\n/g, "<br/>");
    return {
      subject: `[Contact] ${subjectLine}`,
      html: wrap(
        "New contact form message",
        `<p><strong>From:</strong> ${fromName} &lt;${fromEmail}&gt;</p>
         <p><strong>Subject:</strong> ${esc(subjectLine)}</p>
         <p>${body}</p>`,
      ),
    };
  }

  if (template === "demo_request") {
    const body = esc(vars.message ?? "—").replace(/\n/g, "<br/>");
    return {
      subject: `[Demo] ${vars.company ?? "New lead"} — ${vars.name ?? "Unknown"}`,
      html: wrap(
        "New demo request",
        `<p><strong>Name:</strong> ${esc(vars.name ?? "—")}</p>
         <p><strong>Company:</strong> ${esc(vars.company ?? "—")}</p>
         <p><strong>Email:</strong> ${esc(vars.email ?? "—")}</p>
         <p><strong>Website:</strong> ${esc(vars.website ?? "—")}</p>
         <p><strong>Message:</strong><br/>${body}</p>`,
      ),
    };
  }

  throw new Error(`Unknown template: ${template}`);
}

/** Plain-text notice lines for Auth mailer templates ({{ .Data.marvi_* }}). */
function authNoticeCopy(
  template: Template,
  locale: Locale,
  vars: Record<string, string>,
): { title: string; body: string; cta: string } {
  const name = vars.name ?? (locale === "tr" ? "üye" : "member");
  if (template === "welcome_application") {
    return locale === "tr"
      ? {
        title: "Başvurunuz alındı",
        body:
          `Merhaba ${name}, başvurunuz bize ulaştı. Ekibimiz profilinizi inceleyecek. Şehir: ${vars.city ?? "İstanbul"}.`,
        cta: "Marvi Society'yi aç",
      }
      : {
        title: "Application received",
        body:
          `Hi ${name}, we received your application. Our team will review your profile. City: ${vars.city ?? "Istanbul"}.`,
        cta: "Open Marvi Society",
      };
  }
  if (template === "membership_approved") {
    return locale === "tr"
      ? {
        title: "Kaydınız onaylandı",
        body:
          `Tebrikler ${name}! Marvi Society creator üyeliğiniz onaylandı. Uygulamada Explore sekmesine gidin.`,
        cta: "Uygulamayı aç",
      }
      : {
        title: "Registration approved",
        body:
          `Congratulations ${name}! Your Marvi Society creator membership is approved. Open Explore in the app.`,
        cta: "Open the app",
      };
  }
  if (template === "admin_message") {
    return {
      title: vars.subject ?? "Marvi Society",
      body: String(vars.body ?? "").slice(0, 1500),
      cta: locale === "tr" ? "Marvi Society'yi aç" : "Open Marvi Society",
    };
  }
  if (template === "invite_code") {
    const code = vars.invite_code ?? "";
    return locale === "tr"
      ? {
        title: "Davet kodunuz",
        body: `Marvi Society davet kodunuz: ${code}. Bu e-posta ile kayıt olun ve kodu girin.`,
        cta: "Daveti kabul et",
      }
      : {
        title: "Your invite code",
        body: `Your Marvi Society invite code is ${code}. Sign up with this email and enter the code.`,
        cta: "Accept invite",
      };
  }
  if (template === "contact_form") {
    return {
      title: `[Contact] ${vars.subject ?? "Support"}`,
      body:
        `From: ${vars.name ?? "—"} <${vars.email ?? "—"}>\n${String(vars.message ?? "").slice(0, 1200)}`,
      cta: "Open dashboard",
    };
  }
  if (template === "demo_request") {
    return {
      title: `[Demo] ${vars.company ?? "Lead"}`,
      body:
        `${vars.name ?? "—"} / ${vars.email ?? "—"} / ${vars.website ?? "—"}\n${String(vars.message ?? "").slice(0, 1200)}`,
      cta: "Open dashboard",
    };
  }
  return {
    title: "Marvi Society",
    body: locale === "tr" ? "Yeni bir bildiriminiz var." : "You have a new notice.",
    cta: "Open",
  };
}

function resolveAuthRecipient(template: Template, toEmail: string, vars: Record<string, string>): string {
  // Internal ops templates go to support inbox when Resend is unavailable.
  if (template === "contact_form" || template === "demo_request") {
    return REPLY_TO;
  }
  return toEmail;
}

function resolveRedirect(template: Template, vars: Record<string, string>): string {
  if (template === "invite_code") {
    const code = String(vars.invite_code ?? "").trim();
    return `${SITE_URL}/invite?code=${encodeURIComponent(code)}`;
  }
  if (template === "contact_form" || template === "demo_request") {
    return `${SITE_URL}/portal/dashboard`;
  }
  if (template === "membership_approved") {
    return `${SITE_URL}/auth/callback?notice=approved`;
  }
  if (template === "welcome_application") {
    return `${SITE_URL}/auth/callback?notice=welcome`;
  }
  return `${SITE_URL}/auth/callback`;
}

async function sendWithResend(to: string, subject: string, html: string) {
  if (!RESEND_API_KEY) {
    throw new Error("waiting_for_RESEND_API_KEY");
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

async function sendAuthOtp(email: string, redirectTo: string, meta: Record<string, unknown>) {
  const otpResponse = await fetch(`${SUPABASE_URL}/auth/v1/otp`, {
    method: "POST",
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      email,
      create_user: false,
      data: meta,
      options: { email_redirect_to: redirectTo },
    }),
  });

  if (!otpResponse.ok) {
    const text = await otpResponse.text();
    throw new Error(`Auth magic link failed (${otpResponse.status}): ${text}`);
  }
}

async function sendViaSupabaseAuth(
  supabase: ReturnType<typeof createClient>,
  email: string,
  redirectTo: string,
  meta: Record<string, unknown>,
): Promise<DeliveryMethod> {
  // Seed metadata for Auth HTML templates ({{ .Data.marvi_* }}).
  const invited = await supabase.auth.admin.inviteUserByEmail(email, {
    redirectTo,
    data: meta,
  });

  if (!invited.error) {
    return "auth_invite";
  }

  const message = invited.error.message?.toLowerCase() ?? "";
  const alreadyExists =
    message.includes("already") ||
    message.includes("registered") ||
    message.includes("exists");

  if (!alreadyExists) {
    throw new Error(`Auth invite failed: ${invited.error.message}`);
  }

  // Refresh metadata on existing user so magic-link template can branch.
  const link = await supabase.auth.admin.generateLink({
    type: "magiclink",
    email,
    options: {
      redirectTo,
      data: meta,
    },
  });
  if (link.error) {
    throw new Error(`Auth generateLink failed: ${link.error.message}`);
  }

  await sendAuthOtp(email, redirectTo, meta);
  return "auth_magiclink";
}

async function deliverOutbox(
  supabase: ReturnType<typeof createClient>,
  outbox: OutboxRow,
): Promise<{ method: DeliveryMethod }> {
  const locale = localeOf(outbox.locale);
  const template = outbox.template as Template;
  const vars = outbox.variables ?? {};

  if (RESEND_API_KEY) {
    const { subject, html } = buildEmail(template, locale, vars);
    await sendWithResend(outbox.to_email, subject, html);
    return { method: "resend" };
  }

  // No Resend: deliver via Supabase Auth mailer (built-in or project SMTP).
  // Built-in Auth mailer is heavily rate-limited (~few/hour). Prefer it for
  // fresh transactional mail; stale backlog should be archived or wait for Resend.
  if (template === "invite_code") {
    const inviteCode = String(vars.invite_code ?? "").trim();
    if (!inviteCode) {
      throw new Error("invite_code missing in outbox variables");
    }
  }

  const notice = authNoticeCopy(template, locale, vars);
  const recipient = resolveAuthRecipient(template, outbox.to_email, vars);
  const redirectTo = resolveRedirect(template, vars);
  const meta = {
    marvi_email_kind: template,
    marvi_email_title: notice.title.slice(0, 120),
    marvi_email_body: notice.body.slice(0, 1500),
    marvi_email_cta: notice.cta.slice(0, 80),
    marvi_locale: locale,
    invite_code: vars.invite_code ?? "",
    marvi_invite: template === "invite_code",
  };

  const method = await sendViaSupabaseAuth(supabase, recipient, redirectTo, meta);
  return { method: method === "auth_invite" && template !== "invite_code" ? "auth_notice" : method };
}

async function processOutboxId(
  supabase: ReturnType<typeof createClient>,
  outboxId: string,
) {
  const { data: row, error: fetchError } = await supabase
    .from("email_outbox")
    .select("id, to_email, template, locale, variables, status")
    .eq("id", outboxId)
    .single();

  if (fetchError || !row) {
    return { ok: false as const, status: 404, error: fetchError?.message ?? "Outbox row not found" };
  }

  const outbox = row as OutboxRow;
  if (outbox.status === "sent") {
    return { ok: true as const, skipped: true, template: outbox.template };
  }

  // Claim row to reduce double-dispatch races.
  const { data: claimed } = await supabase
    .from("email_outbox")
    .update({ status: "sending", error_message: null })
    .eq("id", outboxId)
    .in("status", ["pending", "failed", "sending"])
    .select("id")
    .maybeSingle();

  if (!claimed) {
    return { ok: true as const, skipped: true, template: outbox.template };
  }

  try {
    const delivery = await deliverOutbox(supabase, outbox);
    await supabase
      .from("email_outbox")
      .update({
        status: "sent",
        sent_at: new Date().toISOString(),
        error_message: delivery.method === "resend" ? null : `sent_via:${delivery.method}`,
      })
      .eq("id", outboxId);

    return {
      ok: true as const,
      template: outbox.template,
      to: outbox.to_email,
      method: delivery.method,
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const retryable = /429|rate_limit|over_email_send_rate_limit/i.test(message);
    await supabase
      .from("email_outbox")
      .update({
        status: retryable ? "pending" : "failed",
        error_message: message.slice(0, 500),
      })
      .eq("id", outboxId);
    return {
      ok: false as const,
      status: retryable ? 429 : 500,
      error: message,
      template: outbox.template,
      retryable,
    };
  }
}

Deno.serve(async (req) => {
  if (req.method === "GET") {
    return Response.json({
      ok: true,
      service: "send-email",
      resendConfigured: Boolean(RESEND_API_KEY),
      fromEmailConfigured: Boolean(FROM_EMAIL),
      replyTo: REPLY_TO,
      fallback: RESEND_API_KEY ? "resend" : "supabase_auth",
      inviteFallback: "supabase_auth",
    });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  if (!isAuthorized(req)) {
    return Response.json({ error: "Unauthorized" }, { status: 401 });
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const body = await req.json().catch(() => ({}));

  // Batch flush: { "flush": true, "limit": 40 }
  if (body?.flush === true) {
    const limit = Math.min(Math.max(Number(body.limit ?? 40), 1), 100);
    const { data: rows, error } = await supabase
      .from("email_outbox")
      .select("id, template, status")
      .in("status", ["pending", "failed"])
      .order("created_at", { ascending: true })
      .limit(limit);

    if (error) {
      return Response.json({ error: error.message }, { status: 500 });
    }

    const results = [];
    let pauseMs = RESEND_API_KEY ? 200 : 65_000;
    for (const row of rows ?? []) {
      // Reset failed → pending so claim works consistently.
      if (row.status === "failed") {
        await supabase
          .from("email_outbox")
          .update({ status: "pending", error_message: null })
          .eq("id", row.id);
      }
      const result = await processOutboxId(supabase, row.id);
      results.push(result);
      if (!result.ok && "retryable" in result && result.retryable) {
        // Built-in Auth mailer is ~1 email/minute — stop early and leave rest pending.
        pauseMs = 65_000;
        break;
      }
      await new Promise((r) => setTimeout(r, pauseMs));
    }

    const sent = results.filter((r) => r.ok && !("skipped" in r && r.skipped)).length;
    const failed = results.filter((r) => !r.ok).length;
    const skipped = results.filter((r) => r.ok && "skipped" in r && r.skipped).length;
    return Response.json({ ok: true, flush: true, sent, failed, skipped, results });
  }

  const outboxId = body.outbox_id as string | undefined;
  if (!outboxId) {
    return Response.json({ error: "outbox_id or flush required" }, { status: 400 });
  }

  const result = await processOutboxId(supabase, outboxId);
  if (!result.ok) {
    return Response.json({ error: result.error }, { status: result.status ?? 500 });
  }
  return Response.json(result);
});
