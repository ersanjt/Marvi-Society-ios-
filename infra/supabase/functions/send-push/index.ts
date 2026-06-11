// Supabase Edge Function scaffold — wire APNs/FCM credentials in production.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  );

  const { user_id, title, body, data } = await req.json();

  const { data: tokens } = await supabase
    .from("device_tokens")
    .select("token, platform")
    .eq("user_id", user_id);

  // TODO: send via APNs/FCM using tokens
  console.log("send-push", { user_id, title, body, data, tokens });

  return Response.json({ ok: true, delivered: tokens?.length ?? 0 });
});
