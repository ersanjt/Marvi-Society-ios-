import { BrandLockup } from "@/components/brand/BrandMark";
import Link from "next/link";
import { PortalSignOut } from "./PortalSignOut";
import { isCurrentUserAdmin } from "@/lib/auth/admin";
import { PORTAL_NAV } from "@/config/site";

export async function PortalNav() {
  const showAdmin = await isCurrentUserAdmin();

  return (
    <div className="border-b border-border bg-panel">
      <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-3 md:px-6">
        <Link href="/" className="transition hover:opacity-90">
          <BrandLockup subtitle="Venue portal" size={36} />
        </Link>
        <nav className="flex items-center gap-4 text-sm font-semibold">
          {PORTAL_NAV.map((item) => (
            <Link key={item.href} href={item.href} className="text-graphite transition hover:text-rose">
              {item.label}
            </Link>
          ))}
          {showAdmin && (
            <Link href="/admin" className="text-graphite transition hover:text-rose">
              Admin
            </Link>
          )}
          <PortalSignOut />
        </nav>
      </div>
    </div>
  );
}
