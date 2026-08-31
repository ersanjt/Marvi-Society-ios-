import { requireAdmin } from "@/lib/auth/admin";
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";
import { EmptyState, MarviScreen, PageHeader, StatusPill, SyncBanner } from "@/components/design/MarviUI";
import { IconShield } from "@/components/design/MarviIcons";
import { getI18n } from "@/lib/i18n/locale";
import { getPortalAdminDict } from "@/lib/i18n/portal-admin";
import { SafetyStatusForm } from "@/components/admin/SafetyStatusForm";

export async function generateMetadata() {
  const { locale } = await getI18n();
  return { title: getPortalAdminDict(locale).admin.safety.metaTitle };
}

type Report = {
  id: string;
  reporter_email: string | null;
  category: string;
  body: string;
  status: string;
  created_at: string;
  admin_notes: string | null;
};

export default async function AdminSafetyPage() {
  const { locale } = await getI18n();
  const dict = getPortalAdminDict(locale);
  const s = dict.admin.safety;

  const auth = await requireAdmin();
  if (!auth.ok) {
    redirect("/portal/login?next=/admin/safety");
  }

  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_list_safety_reports", { p_limit: 80 });
  const reports = (data ?? []) as Report[];

  return (
    <MarviScreen>
      <div className="mx-auto max-w-6xl px-4 py-10 md:px-6 md:py-12">
        <PageHeader eyebrow={s.eyebrow} title={s.title} subtitle={s.subtitle} />
        {error ? (
          <div className="mt-6">
            <SyncBanner tone="error" message={error.message} />
          </div>
        ) : null}
        {reports.length === 0 ? (
          <div className="mt-8">
            <EmptyState icon={<IconShield size={24} />} title={s.emptyTitle} body={s.emptyBody} />
          </div>
        ) : (
          <ul className="mt-8 space-y-3">
            {reports.map((report) => (
              <li key={report.id} className="marvi-card space-y-2">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <p className="text-xs uppercase tracking-wide text-muted">{report.category}</p>
                    <p className="mt-1 text-sm text-graphite">{report.body}</p>
                    <p className="mt-2 text-xs text-muted">
                      {report.reporter_email ?? "member"} · {new Date(report.created_at).toLocaleString()}
                    </p>
                  </div>
                  <StatusPill label={report.status} tone="tomato" />
                </div>
                <SafetyStatusForm id={report.id} current={report.status} labels={s} />
              </li>
            ))}
          </ul>
        )}
      </div>
    </MarviScreen>
  );
}
