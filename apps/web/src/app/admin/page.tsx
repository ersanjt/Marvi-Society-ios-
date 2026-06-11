import { requireAdmin } from "@/lib/auth/admin";
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

export const metadata = { title: "Admin console" };

type AdminTask = {
  id: string;
  type: string;
  title: string;
  subtitle: string;
  priority: string;
  status: string;
  created_at: string;
};

export default async function AdminPage() {
  const auth = await requireAdmin();
  if (!auth.ok) {
    redirect("/portal/login?next=/admin");
  }

  const supabase = await createClient();
  const { data, error } = await supabase
    .from("admin_tasks")
    .select("id, type, title, subtitle, priority, status, created_at")
    .eq("status", "open")
    .order("created_at", { ascending: false })
    .limit(20);

  const tasks: AdminTask[] = data ?? [];

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

      <div className="mt-8 space-y-3">
        {tasks.length === 0 ? (
          <div className="marvi-card p-8 text-center text-muted">No open review tasks.</div>
        ) : (
          tasks.map((task) => (
            <article key={task.id} className="marvi-card flex flex-wrap items-center justify-between gap-4">
              <div>
                <p className="text-xs font-bold uppercase text-gold">{task.type.replace(/_/g, " ")}</p>
                <h2 className="font-bold text-ink">{task.title}</h2>
                <p className="text-sm text-muted">{task.subtitle}</p>
              </div>
              <div className="flex gap-2">
                <form action={`/api/admin/tasks/${task.id}/approve`} method="post">
                  <button type="submit" className="marvi-btn-primary">
                    Approve
                  </button>
                </form>
                <form action={`/api/admin/tasks/${task.id}/reject`} method="post">
                  <button type="submit" className="marvi-btn-secondary">
                    Reject
                  </button>
                </form>
              </div>
            </article>
          ))
        )}
      </div>
    </div>
  );
}
