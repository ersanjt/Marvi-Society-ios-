import { requireAdmin } from "@/lib/auth/admin";
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";
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
  return { title: getPortalAdminDict(locale).admin.ops.metaTitle };
}

type Health = {
  open_tasks?: number;
  live_offers?: number;
  active_bookings?: number;
  pending_emails?: number;
  failed_emails?: number;
  pending_push?: number;
  members?: number;
  venues?: number;
  deletion_requests_open?: number;
};

type EmailRow = {
  id: string;
  to_email: string;
  template: string;
  locale: string;
  status: string;
  error_message: string | null;
  created_at: string;
  sent_at: string | null;
};

type ActivityRow = {
  id: string;
  event_name?: string;
  name?: string;
  entity_type?: string;
  entity_id?: string;
  created_at: string;
  actor_user_id?: string | null;
};

export default async function AdminOpsPage() {
  const { locale } = await getI18n();
  const dict = getPortalAdminDict(locale);
  const o = dict.admin.ops;

  const auth = await requireAdmin();
  if (!auth.ok) {
    redirect("/portal/login?next=/admin/ops");
  }

  const supabase = await createClient();

  const [{ data: healthRaw, error: healthError }, { data: emailsRaw, error: emailError }, { data: activityRaw, error: activityError }] =
    await Promise.all([
      supabase.rpc("admin_system_health"),
      supabase.rpc("admin_list_email_outbox", { p_limit: 40 }),
      supabase.rpc("admin_list_activity", { p_limit: 40 }),
    ]);

  const health = (healthRaw ?? {}) as Health;
  const emails = (emailsRaw ?? []) as EmailRow[];
  const activity = (activityRaw ?? []) as ActivityRow[];
  const error = healthError?.message || emailError?.message || activityError?.message;

  return (
    <div className="mx-auto max-w-6xl px-4 py-10 md:px-6 md:py-12">
      <PageHeader eyebrow={o.eyebrow} title={o.title} subtitle={o.subtitle} />

      <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <MetricTile icon={<IconShield size={18} />} value={String(health.open_tasks ?? 0)} label={dict.admin.queue.openTasks} tone="rose" />
        <MetricTile icon={<IconSparkles size={18} />} value={String(health.live_offers ?? 0)} label={dict.admin.queue.liveOffers} tone="emerald" />
        <MetricTile icon={<IconCalendar size={18} />} value={String(health.active_bookings ?? 0)} label={dict.admin.queue.bookings} tone="blue" />
        <MetricTile icon={<IconBuilding size={18} />} value={String(health.venues ?? 0)} label={o.venues} tone="gold" />
        <MetricTile icon={<IconShield size={18} />} value={String(health.pending_emails ?? 0)} label={o.pendingEmails} tone="gold" />
        <MetricTile icon={<IconShield size={18} />} value={String(health.failed_emails ?? 0)} label={o.failedEmails} tone="tomato" />
        <MetricTile icon={<IconSparkles size={18} />} value={String(health.pending_push ?? 0)} label={o.pendingPush} tone="blue" />
        <MetricTile icon={<IconCalendar size={18} />} value={String(health.deletion_requests_open ?? 0)} label={o.openDeletions} tone="tomato" />
      </div>

      {error ? (
        <div className="mt-8">
          <SyncBanner message={tReplace(o.loadError, { message: error })} />
        </div>
      ) : null}

      <section className="mt-10">
        <h2 className="text-lg font-semibold text-ink">{o.recentEmails}</h2>
        <div className="mt-4 overflow-hidden rounded-marvi border border-border bg-panel">
          {emails.length === 0 ? (
            <p className="px-4 py-6 text-sm text-muted">{o.noEmails}</p>
          ) : (
            <ul className="divide-y divide-border">
              {emails.map((row) => (
                <li key={row.id} className="grid gap-1 px-4 py-3 text-sm md:grid-cols-[1.2fr_1fr_0.6fr_0.8fr]">
                  <span className="font-medium text-ink">{row.template}</span>
                  <span className="text-graphite">{row.to_email}</span>
                  <span className={row.status === "failed" ? "text-tomato" : "text-muted"}>{row.status}</span>
                  <span className="text-muted">{new Date(row.created_at).toLocaleString(locale === "tr" ? "tr-TR" : "en-GB")}</span>
                  {row.error_message ? <span className="md:col-span-4 text-xs text-tomato">{row.error_message}</span> : null}
                </li>
              ))}
            </ul>
          )}
        </div>
      </section>

      <section className="mt-10">
        <h2 className="text-lg font-semibold text-ink">{o.recentActivity}</h2>
        <div className="mt-4 overflow-hidden rounded-marvi border border-border bg-panel">
          {activity.length === 0 ? (
            <p className="px-4 py-6 text-sm text-muted">{o.noActivity}</p>
          ) : (
            <ul className="divide-y divide-border">
              {activity.map((row) => (
                <li key={row.id} className="grid gap-1 px-4 py-3 text-sm md:grid-cols-[1.4fr_1fr_0.8fr]">
                  <span className="font-medium text-ink">{row.event_name || row.name || "event"}</span>
                  <span className="text-graphite">
                    {[row.entity_type, row.entity_id].filter(Boolean).join(" · ") || "—"}
                  </span>
                  <span className="text-muted">{new Date(row.created_at).toLocaleString(locale === "tr" ? "tr-TR" : "en-GB")}</span>
                </li>
              ))}
            </ul>
          )}
        </div>
      </section>
    </div>
  );
}
