import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

type ProvisionBody = {
  email?: string;
  password?: string;
  full_name?: string;
  locale?: string;
  city?: string;
  instagram_handle?: string;
  auto_approve?: boolean;
  send_welcome_email?: boolean;
};

async function assertAdmin(req: Request, supabaseUrl: string, anonKey: string) {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return { ok: false as const, status: 401, error: "Missing Authorization header" };
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return { ok: false as const, status: 401, error: "Invalid session" };
  }

  const { data: profile } = await userClient
    .from("profiles")
    .select("role")
    .eq("id", userData.user.id)
    .maybeSingle();

  if (profile?.role !== "admin") {
    return { ok: false as const, status: 403, error: "Admin access required" };
  }

  return { ok: true as const, adminUserId: userData.user.id };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

  if (!supabaseUrl || !serviceRoleKey || !anonKey) {
    return Response.json({ error: "Supabase env not configured" }, { status: 500 });
  }

  const auth = await assertAdmin(req, supabaseUrl, anonKey);
  if (!auth.ok) {
    return Response.json({ error: auth.error }, { status: auth.status });
  }

  const body = (await req.json()) as ProvisionBody;
  const email = body.email?.trim().toLowerCase() ?? "";
  const password = body.password?.trim() || crypto.randomUUID().replace(/-/g, "").slice(0, 16);
  const fullName = body.full_name?.trim() || email.split("@")[0] || "Creator";
  const locale = body.locale?.trim() || "en";
  const city = body.city?.trim() || "istanbul";
  const instagramHandle = body.instagram_handle?.trim() || "";
  const autoApprove = body.auto_approve !== false;
  const sendWelcomeEmail = body.send_welcome_email !== false;

  if (!email || !email.includes("@")) {
    return Response.json({ error: "Valid email required" }, { status: 400 });
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: {
      full_name: fullName,
      locale,
      city,
      instagram_handle: instagramHandle,
    },
  });

  if (createError || !created.user) {
    return Response.json({ error: createError?.message ?? "Could not create user" }, { status: 500 });
  }

  const userId = created.user.id;

  if (autoApprove) {
    await admin.from("profiles").update({ status: "approved", role: "creator" }).eq("id", userId);
    await admin.from("creator_profiles").update({ status: "approved", city }).eq("user_id", userId);
  }

  if (sendWelcomeEmail) {
    await admin.rpc("queue_transactional_email", {
      p_user_id: userId,
      p_to_email: email,
      p_template: autoApprove ? "membership_approved" : "welcome_application",
      p_locale: locale,
      p_variables: { name: fullName, city, site_url: "https://marvisociety.com" },
    });
  }

  return Response.json({
    ok: true,
    user_id: userId,
    email,
    temporary_password: body.password ? undefined : password,
    auto_approved: autoApprove,
  });
});
