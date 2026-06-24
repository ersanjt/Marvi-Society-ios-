import { BrandLockup } from "@/components/brand/BrandMark";
import { MarviScreen } from "@/components/design/MarviUI";
import { LocaleSwitcher } from "@/components/marketing/LocaleSwitcher";
import { getI18n } from "@/lib/i18n/locale";
import { getPortalAdminDict } from "@/lib/i18n/portal-admin";
import Link from "next/link";

const ADMIN_NAV_HREFS = [
  { href: "/admin", key: "queue" as const },
  { href: "/admin/users", key: "users" as const },
  { href: "/admin/broadcast", key: "broadcast" as const },
];

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const { locale } = await getI18n();
  const dict = getPortalAdminDict(locale);
  const a = dict.admin;

  return (
    <div className="min-h-screen bg-surface text-ink">
      <header className="sticky top-0 z-40 border-b border-border bg-panel/95 backdrop-blur-md">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-4 px-4 py-3 md:px-6 md:py-4">
          <Link href="/admin" className="transition hover:opacity-90">
            <BrandLockup subtitle={a.subtitle} size={40} />
          </Link>
          <nav className="flex items-center gap-2 overflow-x-auto md:gap-3">
            {ADMIN_NAV_HREFS.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                className="whitespace-nowrap rounded-marvi px-3 py-2 text-sm font-semibold text-graphite transition hover:bg-panel-elevated hover:text-rose"
              >
                {a.nav[item.key]}
              </Link>
            ))}
            <Link href="/portal/dashboard" className="whitespace-nowrap text-sm font-semibold text-muted hover:text-rose">
              {a.nav.portal}
            </Link>
            <Link href="/" className="whitespace-nowrap text-sm font-semibold text-muted hover:text-rose">
              {a.nav.site}
            </Link>
            <LocaleSwitcher current={locale} />
          </nav>
        </div>
      </header>
      <MarviScreen>{children}</MarviScreen>
    </div>
  );
}
