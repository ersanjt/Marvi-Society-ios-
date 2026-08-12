import { requireAdmin } from "@/lib/auth/admin";
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";
import { PageHeader } from "@/components/design/MarviUI";
import { AdminCampaignBoard } from "@/components/admin/AdminCampaignBoard";
import { getI18n } from "@/lib/i18n/locale";
import { getPortalAdminDict } from "@/lib/i18n/portal-admin";

export async function generateMetadata() {
  const { locale } = await getI18n();
  const dict = getPortalAdminDict(locale);
  return { title: `${dict.admin.nav.campaigns ?? "Campaigns"} · Admin` };
}

export default async function AdminCampaignsPage() {
  const gate = await requireAdmin();
  if (!gate.ok) redirect("/portal/login");

  const { locale } = await getI18n();
  const dict = getPortalAdminDict(locale);
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("offers")
    .select("id,title,status,date_label,capacity,remaining_slots,deleted_at,admin_block_reason,created_at,venue_profiles(venue_name,area)")
    .order("created_at", { ascending: false })
    .limit(100);

  return (
    <div className="mx-auto max-w-6xl px-4 py-8 md:px-6">
      <PageHeader
        eyebrow={dict.admin.subtitle}
        title={dict.admin.nav.campaigns ?? "Campaigns"}
        subtitle={
          locale === "tr"
            ? "Kampanyaları onayla, yayınla, engelle, tamamla veya sil. Değişiklikler Activity / Ops’ta izlenir."
            : "Approve, publish, block, complete, or delete campaigns. Changes appear in Activity / Ops."
        }
      />
      {error ? (
        <p className="mt-6 text-sm font-semibold text-tomato">{error.message}</p>
      ) : (
        <div className="mt-8">
          <AdminCampaignBoard initialCampaigns={data ?? []} />
        </div>
      )}
    </div>
  );
}
