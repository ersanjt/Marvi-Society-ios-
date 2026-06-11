import { createClient } from "@/lib/supabase/server";

export async function getSessionUser() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  return user;
}

export async function isCurrentUserAdmin() {
  const user = await getSessionUser();
  if (!user) return false;

  const supabase = await createClient();
  const { data } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .maybeSingle();

  return data?.role === "admin";
}

export async function requireAdmin() {
  const user = await getSessionUser();
  if (!user) {
    return { ok: false as const, status: 401, error: "Authentication required" };
  }

  const admin = await isCurrentUserAdmin();
  if (!admin) {
    return { ok: false as const, status: 403, error: "Admin access required" };
  }

  return { ok: true as const, user };
}
