import { LocaleSwitcher } from "@/components/marketing/LocaleSwitcher";
import { BrandLockup } from "@/components/brand/BrandMark";
import Link from "next/link";
import { PortalSignOut } from "./PortalSignOut";
import { isCurrentUserAdmin } from "@/lib/auth/admin";
import type { Locale } from "@/lib/i18n/dictionaries";
import type { PortalAdminDict } from "@/lib/i18n/portal-admin";

const PORTAL_NAV_HREFS = [
  { href: "/portal/dashboard", key: "dashboard" as const },
  { href: "/portal/campaigns/new", key: "newCampaign" as const },
  { href: "/portal/creators", key: "creators" as const },
  { href: "/portal/reviews", key: "reviews" as const },
];

export async function PortalNav({ dict, locale }: { dict: PortalAdminDict; locale: Locale }) {
  const showAdmin = await isCurrentUserAdmin();
  const p = dict.portal;

  return (
    <div className="sticky top-0 z-40 border-b border-border bg-panel/95 backdrop-blur-md">
      <div className="mx-auto flex max-w-6xl items-center justify-between gap-3 px-4 py-3 md:px-6">
        <Link href="/portal/dashboard" className="transition hover:opacity-90">
          <BrandLockup subtitle={p.subtitle} size={36} />
        </Link>
        <nav className="flex items-center gap-1 overflow-x-auto md:gap-2">
          {PORTAL_NAV_HREFS.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="whitespace-nowrap rounded-marvi px-3 py-2 text-sm font-semibold text-graphite transition hover:bg-panel-elevated hover:text-rose"
            >
              {p.nav[item.key]}
            </Link>
          ))}
          {showAdmin ? (
            <Link
              href="/admin"
              className="whitespace-nowrap rounded-marvi px-3 py-2 text-sm font-semibold text-gold transition hover:bg-panel-elevated"
            >
              {p.nav.admin}
            </Link>
          ) : null}
          <LocaleSwitcher current={locale} />
          <PortalSignOut label={dict.common.signOut} />
        </nav>
      </div>
    </div>
  );
}
