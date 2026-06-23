import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

type DeleteBody = {
  confirm?: string;
};

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

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return Response.json({ error: "Missing Authorization header" }, { status: 401 });
  }

  const body = (await req.json()) as DeleteBody;
  if (body.confirm?.trim().toUpperCase() !== "DELETE") {
    return Response.json({ error: 'Type DELETE in confirm field to permanently delete your account.' }, { status: 400 });
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return Response.json({ error: "Invalid session" }, { status: 401 });
  }

  const userId = userData.user.id;

  const { error: rpcError } = await userClient.rpc("delete_own_account");
  if (rpcError) {
    return Response.json({ error: rpcError.message }, { status: 500 });
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
  if (deleteError) {
    return Response.json({ error: deleteError.message }, { status: 500 });
  }

  return Response.json({
    ok: true,
    message: "Your Marvi Society account has been permanently deleted.",
  });
});
