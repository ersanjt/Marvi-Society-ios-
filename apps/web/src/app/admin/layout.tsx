import Link from "next/link";

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-surface text-ink">
      <header className="border-b border-white/10 bg-panel">
        <div className="mx-auto flex max-w-5xl items-center justify-between gap-4 px-4 py-4 md:px-6">
          <div>
            <p className="text-xs font-bold uppercase tracking-widest text-rose">Marvi Society</p>
            <p className="text-sm text-muted">Operations console</p>
          </div>
          <nav className="flex items-center gap-3 text-sm font-semibold">
            <Link href="/admin" className="text-ink hover:text-rose">
              Queue
            </Link>
            <Link href="/portal/dashboard" className="text-muted hover:text-ink">
              Venue portal
            </Link>
            <Link href="/" className="text-muted hover:text-ink">
              Site
            </Link>
          </nav>
        </div>
      </header>
      {children}
    </div>
  );
}
