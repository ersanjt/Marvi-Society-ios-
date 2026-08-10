import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

type DeleteBody = {
  confirm?: string;
};

type StorageAdmin = ReturnType<typeof createClient>;

async function listFilesRecursively(
  admin: StorageAdmin,
  bucket: string,
  prefix: string,
): Promise<string[]> {
  const paths: string[] = [];
  let offset = 0;

  while (true) {
    const { data, error } = await admin.storage.from(bucket).list(prefix, {
      limit: 100,
      offset,
      sortBy: { column: "name", order: "asc" },
    });
    if (error) throw new Error(`${bucket} list failed: ${error.message}`);
    if (!data?.length) break;

    for (const item of data) {
      const path = `${prefix}/${item.name}`;
      if (item.id) {
        paths.push(path);
      } else {
        paths.push(...await listFilesRecursively(admin, bucket, path));
      }
    }

    if (data.length < 100) break;
    offset += data.length;
  }

  return paths;
}

async function deleteUserStorage(admin: StorageAdmin, userId: string) {
  for (const bucket of ["profile-media", "venue-media"]) {
    const paths = await listFilesRecursively(admin, bucket, userId);
    for (let index = 0; index < paths.length; index += 100) {
      const { error } = await admin.storage.from(bucket).remove(paths.slice(index, index + 100));
      if (error) throw new Error(`${bucket} removal failed: ${error.message}`);
    }
  }
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

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Public profile and venue media must not survive account deletion.
  // Remove Storage first so a transient Storage failure leaves the account
  // intact and retryable instead of creating an unrecoverable half-delete.
  try {
    await deleteUserStorage(admin, userId);
  } catch (error) {
    console.error("Account media cleanup failed", error);
    return Response.json({ error: "Could not remove account media. Please try again." }, { status: 500 });
  }

  const { error: rpcError } = await userClient.rpc("delete_own_account");
  if (rpcError) {
    return Response.json({ error: rpcError.message }, { status: 500 });
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
  if (deleteError) {
    return Response.json({ error: deleteError.message }, { status: 500 });
  }

  return Response.json({
    ok: true,
    message: "Your Marvi Society account has been permanently deleted.",
  });
});
