import Link from "next/link";
import { PortalSignOut } from "./PortalSignOut";
import { isCurrentUserAdmin } from "@/lib/auth/admin";

export async function PortalNav() {
  const showAdmin = await isCurrentUserAdmin();

  return (
    <div className="border-b border-black/5 bg-white">
      <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-3 md:px-6">
        <Link href="/" className="text-sm font-bold text-emerald">
          ← Marvi Society
        </Link>
        <nav className="flex items-center gap-4 text-sm font-semibold">
          <Link href="/portal/dashboard" className="text-graphite hover:text-emerald">
            Dashboard
          </Link>
          <Link href="/portal/reviews" className="text-graphite hover:text-emerald">
            Reviews
          </Link>
          <Link href="/portal/creators" className="text-graphite hover:text-emerald">
            Creators
          </Link>
          <Link href="/portal/campaigns/new" className="text-graphite hover:text-emerald">
            New campaign
          </Link>
          {showAdmin && (
            <Link href="/admin" className="text-graphite hover:text-emerald">
              Admin
            </Link>
          )}
          <PortalSignOut />
        </nav>
      </div>
    </div>
  );
}
