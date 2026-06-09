import Link from "next/link";

export const metadata = { title: "Venue dashboard" };

const METRICS = [
  { label: "Live campaigns", value: "6", trend: "+2 this week" },
  { label: "Matched creators", value: "84", trend: "31 confirmed" },
  { label: "Proof received", value: "89%", trend: "+6% vs last month" },
  { label: "Avg. reach", value: "312K", trend: "per campaign" },
];

export default function PortalDashboardPage() {
  return (
    <div className="mx-auto max-w-6xl px-4 py-12 md:px-6">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-xs font-bold uppercase tracking-widest text-emerald">Venue studio</p>
          <h1 className="font-serif text-3xl font-bold text-ink">Dashboard</h1>
        </div>
        <Link href="/portal/campaigns/new" className="marvi-btn-primary">
          New campaign
        </Link>
      </div>

      <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {METRICS.map((m) => (
          <div key={m.label} className="marvi-card">
            <p className="text-2xl font-bold text-emerald">{m.value}</p>
            <p className="text-sm font-bold text-ink">{m.label}</p>
            <p className="text-xs text-muted">{m.trend}</p>
          </div>
        ))}
      </div>

      <div className="marvi-card mt-8">
        <h2 className="font-bold text-ink">Review queue preview</h2>
        <p className="mt-2 text-sm text-muted">
          Connect Supabase Auth to load live campaigns and bookings. This mirrors the iOS Venue Studio workflow.
        </p>
        <ul className="mt-4 space-y-2 text-sm">
          <li className="rounded-marvi bg-cool px-3 py-2">Rooftop opening night — 15/20 slots matched</li>
          <li className="rounded-marvi bg-cool px-3 py-2">Signature facial launch — proof review pending</li>
        </ul>
      </div>
    </div>
  );
}
