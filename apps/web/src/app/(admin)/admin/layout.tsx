import { BrandLockup } from "@/components/brand/BrandMark";
import Link from "next/link";
import { ADMIN_NAV } from "@/config/site";

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-surface text-ink">
      <header className="border-b border-border bg-panel">
        <div className="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-4 px-4 py-4 md:px-6">
          <BrandLockup subtitle="Operations console" size={40} />
          <nav className="flex flex-wrap items-center gap-3 text-sm font-semibold">
            {ADMIN_NAV.map((item) => (
              <Link key={item.href} href={item.href} className="text-muted transition hover:text-rose">
                {item.label}
              </Link>
            ))}
            <Link href="/portal/dashboard" className="text-muted transition hover:text-rose">
              Venue portal
            </Link>
            <Link href="/" className="text-muted transition hover:text-rose">
              Site
            </Link>
          </nav>
        </div>
      </header>
      {children}
    </div>
  );
}
