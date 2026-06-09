import Link from "next/link";

export const metadata = { title: "Brand login" };

export default function PortalLoginPage() {
  return (
    <div className="mx-auto flex max-w-md flex-col px-4 py-20 md:px-6">
      <div className="marvi-card">
        <h1 className="font-serif text-2xl font-bold text-ink">Brand portal</h1>
        <p className="mt-2 text-sm text-muted">Sign in to manage campaigns, bookings, and metrics.</p>

        <form className="mt-8 space-y-4">
          <label className="block text-sm font-semibold">
            Email
            <input type="email" className="mt-1 w-full rounded-marvi border border-black/10 px-3 py-2" />
          </label>
          <label className="block text-sm font-semibold">
            Password
            <input type="password" className="mt-1 w-full rounded-marvi border border-black/10 px-3 py-2" />
          </label>
          <Link href="/portal/dashboard" className="marvi-btn-primary w-full text-center">
            Sign in
          </Link>
        </form>

        <p className="mt-6 text-center text-xs text-muted">
          No account? <Link href="/demo" className="font-bold text-emerald">Request a demo</Link>
        </p>
      </div>
    </div>
  );
}
