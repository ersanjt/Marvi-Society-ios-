import { requireAdmin } from "@/lib/auth/admin";
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";
import { EmptyState, MarviScreen, PageHeader, StatusPill, SyncBanner } from "@/components/design/MarviUI";
import { IconBuilding } from "@/components/design/MarviIcons";
import { getI18n } from "@/lib/i18n/locale";
import { getPortalAdminDict } from "@/lib/i18n/portal-admin";
import { LeadStatusForm } from "@/components/admin/LeadStatusForm";

export async function generateMetadata() {
  const { locale } = await getI18n();
  return { title: getPortalAdminDict(locale).admin.leads.metaTitle };
}

type Lead = {
  id: string;
  first_name: string;
  last_name: string;
  company: string;
  email: string;
  website: string | null;
  message: string | null;
  status: string | null;
  created_at: string;
};

export default async function AdminLeadsPage() {
  const { locale } = await getI18n();
  const dict = getPortalAdminDict(locale);
  const l = dict.admin.leads;

  const auth = await requireAdmin();
  if (!auth.ok) {
    redirect("/portal/login?next=/admin/leads");
  }

  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_list_demo_requests", { p_limit: 80 });
  const leads = (data ?? []) as Lead[];

  return (
    <MarviScreen>
      <div className="mx-auto max-w-6xl px-4 py-10 md:px-6 md:py-12">
        <PageHeader eyebrow={l.eyebrow} title={l.title} subtitle={l.subtitle} />
        {error ? (
          <div className="mt-6">
            <SyncBanner tone="error" message={error.message} />
          </div>
        ) : null}
        {leads.length === 0 ? (
          <div className="mt-8">
            <EmptyState icon={<IconBuilding size={24} />} title={l.emptyTitle} body={l.emptyBody} />
          </div>
        ) : (
          <ul className="mt-8 space-y-3">
            {leads.map((lead) => (
              <li key={lead.id} className="marvi-card space-y-2">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <p className="font-semibold">
                      {lead.first_name} {lead.last_name} · {lead.company}
                    </p>
                    <p className="text-sm text-muted">{lead.email}</p>
                    {lead.website ? <p className="text-xs text-muted">{lead.website}</p> : null}
                    {lead.message ? <p className="mt-2 text-sm text-graphite">{lead.message}</p> : null}
                  </div>
                  <StatusPill label={lead.status ?? "new"} tone="gold" />
                </div>
                <LeadStatusForm id={lead.id} current={lead.status ?? "new"} labels={l} />
              </li>
            ))}
          </ul>
        )}
      </div>
    </MarviScreen>
  );
}
