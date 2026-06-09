import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

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
  let tasks: AdminTask[] = [];
  let mode = "preview";

  try {
    const supabase = await createClient();
    const { data } = await supabase
      .from("admin_tasks")
      .select("id, type, title, subtitle, priority, status, created_at")
      .eq("status", "open")
      .order("created_at", { ascending: false })
      .limit(20);
    if (data) {
      tasks = data;
      mode = "live";
    }
  } catch {
    tasks = [
      { id: "1", type: "creator_application", title: "Aylin Demir", subtitle: "41.8K audience", priority: "High", status: "open", created_at: "" },
      { id: "2", type: "proof_review", title: "Kadıköy Brew Lab proof", subtitle: "1 link submitted", priority: "Medium", status: "open", created_at: "" },
    ];
  }

  return (
    <div className="mx-auto max-w-5xl px-4 py-12 md:px-6">
      <div className="flex items-center justify-between gap-4">
        <div>
          <p className="text-xs font-bold uppercase tracking-widest text-emerald">Operations</p>
          <h1 className="font-serif text-3xl font-bold">Admin review queue</h1>
          <p className="mt-1 text-sm text-muted">Mode: {mode}</p>
        </div>
        <Link href="/portal/dashboard" className="marvi-btn-secondary">Venue portal</Link>
      </div>

      <div className="mt-8 space-y-3">
        {tasks.map((task) => (
          <article key={task.id} className="marvi-card flex flex-wrap items-center justify-between gap-4">
            <div>
              <p className="text-xs font-bold uppercase text-gold">{task.type.replace(/_/g, " ")}</p>
              <h2 className="font-bold text-ink">{task.title}</h2>
              <p className="text-sm text-muted">{task.subtitle}</p>
            </div>
            <div className="flex gap-2">
              <form action={`/api/admin/tasks/${task.id}/approve`} method="post">
                <button className="marvi-btn-primary">Approve</button>
              </form>
              <form action={`/api/admin/tasks/${task.id}/reject`} method="post">
                <button className="marvi-btn-secondary">Reject</button>
              </form>
            </div>
          </article>
        ))}
      </div>
    </div>
  );
}
