import { requireAdmin } from "@/lib/auth/admin";
import { redirect } from "next/navigation";
import { AdminBroadcastForm } from "@/components/admin/AdminBroadcastForm";
import { PageHeader } from "@/components/design/MarviUI";
import { getI18n } from "@/lib/i18n/locale";
import { getPortalAdminDict } from "@/lib/i18n/portal-admin";

export async function generateMetadata() {
  const { locale } = await getI18n();
  return { title: getPortalAdminDict(locale).admin.broadcast.metaTitle };
}

export default async function AdminBroadcastPage() {
  const { locale } = await getI18n();
  const dict = getPortalAdminDict(locale);
  const b = dict.admin.broadcast;

  const auth = await requireAdmin();
  if (!auth.ok) {
    redirect("/portal/login?next=/admin/broadcast");
  }

  return (
    <div className="mx-auto max-w-3xl px-4 py-10 md:px-6 md:py-12">
      <PageHeader eyebrow={b.eyebrow} title={b.title} subtitle={b.subtitle} />

      <div className="mt-10">
        <AdminBroadcastForm dict={dict} />
      </div>
    </div>
  );
}
