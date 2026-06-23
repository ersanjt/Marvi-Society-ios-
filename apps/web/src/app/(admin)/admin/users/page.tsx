import { requireAdmin } from "@/lib/auth/admin";
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";
import { AdminUserDirectory } from "@/components/admin/AdminUserDirectory";

export const metadata = { title: "Admin users" };

export default async function AdminUsersPage() {
  const auth = await requireAdmin();
  if (!auth.ok) {
    redirect("/portal/login?next=/admin/users");
  }

  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_list_users", {
    p_search: null,
    p_status: null,
    p_limit: 100,
  });

  return (
    <div className="mx-auto max-w-5xl px-4 py-10 md:px-6">
      <div>
        <p className="text-xs font-bold uppercase tracking-widest text-blue">Directory</p>
        <h1 className="font-serif text-3xl font-bold">User management</h1>
        <p className="mt-1 text-sm text-muted">
          Approve, block, email, notify, invite, or create accounts directly.
        </p>
      </div>

      {error ? (
        <p className="mt-8 rounded-xl border border-tomato/30 bg-tomato/10 p-4 text-sm text-tomato">
          Run apply-admin-operations.sql in Supabase first. ({error.message})
        </p>
      ) : null}

      <div className="mt-8">
        <AdminUserDirectory initialUsers={data ?? []} />
      </div>
    </div>
  );
}
