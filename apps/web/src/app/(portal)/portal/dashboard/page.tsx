import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

export const metadata = { title: "Venue dashboard" };

type VenueEmbed = { venue_name: string } | { venue_name: string }[] | null;

type OfferRow = {
  id: string;
  title: string;
  status: string;
  capacity: number;
  remaining_slots: number;
  venue_profiles: VenueEmbed;
};

type BookingRow = {
  id: string;
  stage: string;
  proof_status: string;
  offers: { title: string; venue_profiles: VenueEmbed } | null;
};

function venueName(embed: VenueEmbed): string {
  if (!embed) return "Venue";
  if (Array.isArray(embed)) return embed[0]?.venue_name ?? "Venue";
  return embed.venue_name;
}

export default async function PortalDashboardPage() {
  let mode = "preview";
  let offers: OfferRow[] = [];
  let bookings: BookingRow[] = [];
  let userEmail: string | null = null;

  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (user) {
      userEmail = user.email ?? null;
      mode = "live";

      const { data: offerData } = await supabase
        .from("offers")
        .select("id, title, status, capacity, remaining_slots, venue_profiles(venue_name)")
        .order("created_at", { ascending: false })
        .limit(8);

      const { data: bookingData } = await supabase
        .from("bookings")
        .select("id, stage, proof_status, offers(title, venue_profiles(venue_name))")
        .order("created_at", { ascending: false })
        .limit(6);

      if (offerData) offers = offerData as unknown as OfferRow[];
      if (bookingData) bookings = bookingData as unknown as BookingRow[];
    }
  } catch {
    // preview fallback below
  }

  const liveCount = offers.filter((o) => o.status === "live").length;
  const reviewCount = offers.filter((o) => o.status === "review").length;
  const matched = offers.reduce((sum, o) => sum + (o.capacity - o.remaining_slots), 0);
  const proofPending = bookings.filter((b) => b.proof_status === "pending").length;

  const metrics =
    mode === "live"
      ? [
          { label: "Live campaigns", value: String(liveCount), trend: `${reviewCount} in review` },
          { label: "Matched creators", value: String(matched), trend: `${bookings.length} bookings` },
          { label: "Proof pending", value: String(proofPending), trend: "awaiting review" },
          { label: "Total offers", value: String(offers.length), trend: userEmail ?? "venue account" },
        ]
      : [
          { label: "Live campaigns", value: "6", trend: "+2 this week" },
          { label: "Matched creators", value: "84", trend: "31 confirmed" },
          { label: "Proof received", value: "89%", trend: "+6% vs last month" },
          { label: "Avg. reach", value: "312K", trend: "per campaign" },
        ];

  const queueItems =
    mode === "live" && offers.length > 0
      ? offers.map((o) => {
          const venue = venueName(o.venue_profiles);
          const filled = o.capacity - o.remaining_slots;
          return `${o.title} — ${filled}/${o.capacity} slots · ${o.status}`;
        })
      : [
          "Rooftop opening night — 15/20 slots matched",
          "Signature facial launch — proof review pending",
        ];

  return (
    <div className="mx-auto max-w-6xl px-4 py-12 md:px-6">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="marvi-eyebrow">Venue studio</p>
          <h1 className="font-serif text-3xl font-bold text-ink">Dashboard</h1>
          <p className="mt-1 text-sm text-muted">Mode: {mode}</p>
        </div>
        <Link href="/portal/campaigns/new" className="marvi-btn-primary">
          New campaign
        </Link>
      </div>

      <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {metrics.map((m) => (
          <div key={m.label} className="marvi-card">
            <p className="bg-brand-gradient bg-clip-text text-2xl font-bold text-transparent">{m.value}</p>
            <p className="text-sm font-bold text-ink">{m.label}</p>
            <p className="text-xs text-muted">{m.trend}</p>
          </div>
        ))}
      </div>

      <div className="marvi-card mt-8">
        <h2 className="font-bold text-ink">Campaigns & bookings</h2>
        <p className="mt-2 text-sm text-muted">
          {mode === "live"
            ? "Live data from your venue account."
            : "Preview data — sign in with Supabase to load live campaigns."}
        </p>
        <ul className="mt-4 space-y-2 text-sm">
          {queueItems.map((item) => (
            <li key={item} className="rounded-marvi bg-cool px-3 py-2">
              {item}
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
