import { requireAdmin } from "@/lib/auth/admin";
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";
import { AdminUserDirectory } from "@/components/admin/AdminUserDirectory";
import { PageHeader, SyncBanner } from "@/components/design/MarviUI";
import { getI18n } from "@/lib/i18n/locale";
import { getPortalAdminDict, tReplace } from "@/lib/i18n/portal-admin";

export async function generateMetadata() {
  const { locale } = await getI18n();
  return { title: getPortalAdminDict(locale).admin.users.metaTitle };
}

export default async function AdminUsersPage() {
  const { locale } = await getI18n();
  const dict = getPortalAdminDict(locale);
  const u = dict.admin.users;

  const auth = await requireAdmin();
  if (!auth.ok) {
    redirect("/portal/login?next=/admin/users");
  }

  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_list_users", {
    p_search: null,
    p_status: null,
    p_limit: 100,
  });

  return (
    <div className="mx-auto max-w-6xl px-4 py-10 md:px-6 md:py-12">
      <PageHeader eyebrow={u.eyebrow} title={u.title} subtitle={u.subtitle} />

      {error ? (
        <div className="mt-8">
          <SyncBanner
            tone="error"
            message={tReplace(u.sqlError, { message: error.message })}
          />
        </div>
      ) : null}

      <div className="mt-10">
        <AdminUserDirectory dict={dict} locale={locale} initialUsers={data ?? []} />
      </div>
    </div>
  );
}
