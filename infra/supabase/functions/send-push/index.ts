import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v4.14.4/index.ts";

type PushOutboxRow = {
  id: string;
  user_id: string;
  title: string;
  body: string;
  payload: Record<string, string>;
  status: string;
};

const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID") ?? "";
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID") ?? "";
const APNS_KEY_P8 = Deno.env.get("APNS_KEY_P8") ?? "";
const APNS_BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID") ?? "com.marvisociety.app";
const APNS_PRODUCTION = (Deno.env.get("APNS_PRODUCTION") ?? "false") === "true";

let cachedJwt: { token: string; expiresAt: number } | null = null;

async function apnsJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && cachedJwt.expiresAt > now + 60) {
    return cachedJwt.token;
  }

  if (!APNS_KEY_ID || !APNS_TEAM_ID || !APNS_KEY_P8) {
    throw new Error("APNs secrets missing (APNS_KEY_ID, APNS_TEAM_ID, APNS_KEY_P8)");
  }

  const pem = APNS_KEY_P8.includes("BEGIN PRIVATE KEY")
    ? APNS_KEY_P8
    : APNS_KEY_P8.replace(/\\n/g, "\n");

  const privateKey = await importPKCS8(pem, "ES256");
  const token = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: APNS_KEY_ID })
    .setIssuer(APNS_TEAM_ID)
    .setIssuedAt(now)
    .sign(privateKey);

  cachedJwt = { token, expiresAt: now + 3000 };
  return token;
}

async function sendApns(deviceToken: string, title: string, body: string, payload: Record<string, string>) {
  const jwt = await apnsJwt();
  const host = APNS_PRODUCTION ? "api.push.apple.com" : "api.sandbox.push.apple.com";
  const normalizedToken = deviceToken.replace(/\s+/g, "").toLowerCase();

  const response = await fetch(`https://${host}/3/device/${normalizedToken}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": APNS_BUNDLE_ID,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      aps: {
        alert: { title, body },
        sound: "default",
        "mutable-content": 1,
      },
      ...payload,
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`APNs ${response.status}: ${text}`);
  }
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

  let userId = body.user_id as string | undefined;
  let title = body.title as string | undefined;
  let messageBody = body.body as string | undefined;
  let payload = (body.data ?? body.payload ?? {}) as Record<string, string>;
  let outboxRow: PushOutboxRow | null = null;

  if (outboxId) {
    const { data, error } = await supabase
      .from("push_outbox")
      .select("id, user_id, title, body, payload, status")
      .eq("id", outboxId)
      .single();

    if (error || !data) {
      return Response.json({ error: error?.message ?? "Outbox row not found" }, { status: 404 });
    }

    outboxRow = data as PushOutboxRow;
    if (outboxRow.status === "sent") {
      return Response.json({ ok: true, skipped: true });
    }

    userId = outboxRow.user_id;
    title = outboxRow.title;
    messageBody = outboxRow.body;
    payload = (outboxRow.payload ?? {}) as Record<string, string>;
  }

  if (!userId || !title || !messageBody) {
    return Response.json({ error: "outbox_id or user_id/title/body required" }, { status: 400 });
  }

  const { data: tokens, error: tokenError } = await supabase
    .from("device_tokens")
    .select("token, platform")
    .eq("user_id", userId);

  if (tokenError) {
    return Response.json({ error: tokenError.message }, { status: 500 });
  }

  if (!tokens?.length) {
    const message = "No device tokens registered";
    if (outboxRow) {
      await supabase.from("push_outbox").update({ status: "failed", error_message: message }).eq("id", outboxRow.id);
    }
    return Response.json({ ok: false, delivered: 0, error: message });
  }

  try {
    let delivered = 0;
    for (const row of tokens) {
      if (row.platform !== "ios") continue;
      await sendApns(row.token, title, messageBody, payload);
      delivered += 1;
    }

    if (outboxRow) {
      await supabase
        .from("push_outbox")
        .update({ status: "sent", sent_at: new Date().toISOString(), error_message: null })
        .eq("id", outboxRow.id);
    }

    return Response.json({ ok: true, delivered });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (outboxRow) {
      await supabase.from("push_outbox").update({ status: "failed", error_message: message }).eq("id", outboxRow.id);
    }
    return Response.json({ error: message }, { status: 500 });
  }
});
