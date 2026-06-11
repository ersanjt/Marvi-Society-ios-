import { requireAdmin } from "@/lib/auth/admin";
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";
import { AdminTaskQueue } from "@/components/admin/AdminTaskQueue";

export const metadata = { title: "Admin console" };

export default async function AdminPage() {
  const auth = await requireAdmin();
  if (!auth.ok) {
    redirect("/portal/login?next=/admin");
  }

  const supabase = await createClient();
  const { data, error } = await supabase
    .from("admin_tasks")
    .select("id, type, title, subtitle, priority, status, created_at, subject_id")
    .eq("status", "open")
    .order("created_at", { ascending: false })
    .limit(30);

  const tasks = data ?? [];

  return (
    <div className="mx-auto max-w-5xl px-4 py-10 md:px-6">
      <div>
        <p className="text-xs font-bold uppercase tracking-widest text-emerald">Live</p>
        <h1 className="font-serif text-3xl font-bold">Admin review queue</h1>
        <p className="mt-1 text-sm text-muted">
          Approve creators, campaigns, and proof submissions. Changes apply immediately in the mobile app.
        </p>
      </div>

      {error ? (
        <p className="mt-8 rounded-xl border border-tomato/30 bg-tomato/10 p-4 text-sm text-tomato">
          Could not load tasks: {error.message}
        </p>
      ) : null}

      <div className="mt-8">
        <AdminTaskQueue tasks={tasks} />
      </div>
    </div>
  );
}
