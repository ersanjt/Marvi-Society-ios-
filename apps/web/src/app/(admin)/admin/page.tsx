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

  const proofBookingIds = tasks
    .filter((task) => task.type === "proof_review" && task.subject_id)
    .map((task) => task.subject_id as string);

  const { data: proofBookings } = proofBookingIds.length
    ? await supabase
        .from("bookings")
        .select("id, proof_links, guest_name, proof_deadline_label")
        .in("id", proofBookingIds)
    : { data: [] as Array<{ id: string; proof_links: string[] | null; guest_name?: string | null; proof_deadline_label?: string | null }> };

  const proofBookingMap = Object.fromEntries((proofBookings ?? []).map((row) => [row.id, row]));

  const [
    { count: openTasks },
    { count: liveOffers },
    { count: activeBookings },
    { count: reviewCampaigns },
    { count: strikes },
  ] = await Promise.all([
    supabase.from("admin_tasks").select("*", { count: "exact", head: true }).eq("status", "open"),
    supabase.from("offers").select("*", { count: "exact", head: true }).eq("status", "live"),
    supabase.from("bookings").select("*", { count: "exact", head: true }).neq("stage", "cancelled"),
    supabase.from("offers").select("*", { count: "exact", head: true }).eq("status", "review"),
    supabase.from("strikes").select("*", { count: "exact", head: true }),
  ]);

  return (
    <div className="mx-auto max-w-5xl px-4 py-10 md:px-6">
      <div>
        <p className="marvi-eyebrow">Live</p>
        <h1 className="font-serif text-3xl font-bold">Admin review queue</h1>
        <p className="mt-1 text-sm text-muted">
          Approve creators, campaigns, and proof submissions. Changes apply immediately in the mobile app.
        </p>
      </div>

      <div className="mt-8 grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
        <MetricCard label="Open tasks" value={openTasks ?? 0} />
        <MetricCard label="Live offers" value={liveOffers ?? 0} />
        <MetricCard label="Bookings" value={activeBookings ?? 0} />
        <MetricCard label="In review" value={reviewCampaigns ?? 0} />
        <MetricCard label="Strikes" value={strikes ?? 0} />
      </div>

      {error ? (
        <p className="mt-8 rounded-xl border border-tomato/30 bg-tomato/10 p-4 text-sm text-tomato">
          Could not load tasks: {error.message}
        </p>
      ) : null}

      <div className="mt-8">
        <AdminTaskQueue tasks={tasks} proofBookings={proofBookingMap} />
      </div>
    </div>
  );
}

function MetricCard({ label, value }: { label: string; value: number }) {
  return (
    <div className="marvi-card p-4">
      <p className="text-2xl font-bold text-ink">{value}</p>
      <p className="text-xs font-semibold uppercase tracking-wide text-muted">{label}</p>
    </div>
  );
}
