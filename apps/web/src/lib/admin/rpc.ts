import { requireAdmin } from "@/lib/auth/admin";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import type { PostgrestSingleResponse } from "@supabase/supabase-js";

type AdminClient =
  | NonNullable<ReturnType<typeof createAdminClient>>
  | Awaited<ReturnType<typeof createClient>>;

export async function adminRpc<T>(
  run: (client: AdminClient) => PromiseLike<PostgrestSingleResponse<T>>
): Promise<{ ok: true; data: T } | { ok: false; status: number; error: string }> {
  const auth = await requireAdmin();
  if (!auth.ok) {
    return { ok: false, status: auth.status, error: auth.error };
  }

  const admin = createAdminClient();
  const client = admin ?? (await createClient());
  const { data, error } = await run(client);

  if (error) {
    return { ok: false, status: 500, error: error.message };
  }

  return { ok: true, data: data as T };
}
