import { requireAdmin } from "@/lib/auth/admin";
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";
import { AdminTaskQueue } from "@/components/admin/AdminTaskQueue";
import {
  IconBuilding,
  IconCalendar,
  IconShield,
  IconSparkles,
} from "@/components/design/MarviIcons";
import { MetricTile, PageHeader, SyncBanner } from "@/components/design/MarviUI";
import { getI18n } from "@/lib/i18n/locale";
import { getPortalAdminDict, tReplace } from "@/lib/i18n/portal-admin";

export async function generateMetadata() {
  const { locale } = await getI18n();
  return { title: getPortalAdminDict(locale).admin.queue.metaTitle };
}

export default async function AdminPage() {
  const { locale } = await getI18n();
  const dict = getPortalAdminDict(locale);
  const q = dict.admin.queue;

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
    <div className="mx-auto max-w-6xl px-4 py-10 md:px-6 md:py-12">
      <PageHeader eyebrow={q.eyebrow} title={q.title} subtitle={q.subtitle} />

      <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
        <MetricTile icon={<IconShield size={18} />} value={String(openTasks ?? 0)} label={q.openTasks} tone="rose" />
        <MetricTile icon={<IconSparkles size={18} />} value={String(liveOffers ?? 0)} label={q.liveOffers} tone="emerald" />
        <MetricTile icon={<IconCalendar size={18} />} value={String(activeBookings ?? 0)} label={q.bookings} tone="blue" />
        <MetricTile icon={<IconBuilding size={18} />} value={String(reviewCampaigns ?? 0)} label={q.inReview} tone="gold" />
        <MetricTile icon={<IconShield size={18} />} value={String(strikes ?? 0)} label={q.strikes} tone="tomato" />
      </div>

      {error ? (
        <div className="mt-8">
          <SyncBanner tone="error" message={tReplace(q.loadError, { message: error.message })} />
        </div>
      ) : null}

      <div className="mt-10">
        <h2 className="text-xs font-bold uppercase tracking-[0.14em] text-muted">{q.openTasksHeading}</h2>
        <div className="mt-4">
          <AdminTaskQueue dict={dict} locale={locale} tasks={tasks} proofBookings={proofBookingMap} />
        </div>
      </div>
    </div>
  );
}
