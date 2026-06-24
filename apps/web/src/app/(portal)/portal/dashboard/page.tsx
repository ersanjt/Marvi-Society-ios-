import Link from "next/link";
import {
  IconBuilding,
  IconCalendar,
  IconShield,
  IconSparkles,
} from "@/components/design/MarviIcons";
import {
  EmptyState,
  ListRow,
  MarviScreen,
  MetricTile,
  PageHeader,
  StatusPill,
  StudioStatusGrid,
  SyncBanner,
} from "@/components/design/MarviUI";
import { getI18n } from "@/lib/i18n/locale";
import { getPortalAdminDict, tReplace } from "@/lib/i18n/portal-admin";
import {
  formatStatusLabel,
  offerStatusTone,
  proofStatusTone,
} from "@/lib/operational/status";
import { createClient } from "@/lib/supabase/server";

export async function generateMetadata() {
  const { locale } = await getI18n();
  return { title: getPortalAdminDict(locale).portal.dashboard.metaTitle };
}

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

function venueName(embed: VenueEmbed, fallback: string): string {
  if (!embed) return fallback;
  if (Array.isArray(embed)) return embed[0]?.venue_name ?? fallback;
  return embed.venue_name;
}

export default async function PortalDashboardPage() {
  const { locale } = await getI18n();
  const dict = getPortalAdminDict(locale);
  const d = dict.portal.dashboard;
  const c = dict.common;

  let mode: "live" | "preview" = "preview";
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
        .limit(12);

      const { data: bookingData } = await supabase
        .from("bookings")
        .select("id, stage, proof_status, offers(title, venue_profiles(venue_name))")
        .order("created_at", { ascending: false })
        .limit(8);

      if (offerData) offers = offerData as unknown as OfferRow[];
      if (bookingData) bookings = bookingData as unknown as BookingRow[];
    }
  } catch {
    // preview fallback
  }

  const liveCount = offers.filter((o) => o.status === "live").length;
  const reviewCount = offers.filter((o) => o.status === "review").length;
  const draftCount = offers.filter((o) => o.status === "draft").length;
  const matched = offers.reduce((sum, o) => sum + (o.capacity - o.remaining_slots), 0);
  const proofPending = bookings.filter((b) => b.proof_status === "pending").length;

  const metrics =
    mode === "live"
      ? [
          { label: d.liveCampaigns, value: String(liveCount), hint: `${reviewCount} ${d.inReview}`, icon: <IconSparkles size={18} />, tone: "rose" as const },
          { label: d.matchedCreators, value: String(matched), hint: `${bookings.length} ${d.bookings}`, icon: <IconCalendar size={18} />, tone: "emerald" as const },
          { label: d.proofPending, value: String(proofPending), hint: d.awaitingReview, icon: <IconShield size={18} />, tone: "gold" as const },
          { label: d.totalOffers, value: String(offers.length), hint: userEmail ?? d.venueAccount, icon: <IconBuilding size={18} />, tone: "aubergine" as const },
        ]
      : [
          { label: d.liveCampaigns, value: "6", hint: d.thisWeek, icon: <IconSparkles size={18} />, tone: "rose" as const },
          { label: d.matchedCreators, value: "84", hint: `31 ${d.confirmed}`, icon: <IconCalendar size={18} />, tone: "emerald" as const },
          { label: d.proofReceived, value: "89%", hint: d.vsLastMonth, icon: <IconShield size={18} />, tone: "gold" as const },
          { label: d.avgReach, value: "312K", hint: d.perCampaign, icon: <IconBuilding size={18} />, tone: "aubergine" as const },
        ];

  const studioGrid =
    mode === "live"
      ? [
          { label: d.live, value: String(liveCount), tone: "emerald" as const },
          { label: d.inReview, value: String(reviewCount), tone: "gold" as const },
          { label: d.drafts, value: String(draftCount), tone: "muted" as const },
          { label: d.bookings, value: String(bookings.length), tone: "blue" as const },
          { label: d.matched, value: String(matched), tone: "rose" as const },
          { label: d.proofWait, value: String(proofPending), tone: "tomato" as const },
        ]
      : [
          { label: d.live, value: "6", tone: "emerald" as const },
          { label: d.inReview, value: "2", tone: "gold" as const },
          { label: d.drafts, value: "1", tone: "muted" as const },
          { label: d.bookings, value: "31", tone: "blue" as const },
          { label: d.matched, value: "84", tone: "rose" as const },
          { label: d.proofWait, value: "4", tone: "tomato" as const },
        ];

  const displayOffers =
    mode === "live" && offers.length > 0
      ? offers
      : ([
          { id: "p1", title: "Rooftop opening night", status: "live", capacity: 20, remaining_slots: 5, venue_profiles: { venue_name: "Demo Venue" } },
          { id: "p2", title: "Signature facial launch", status: "review", capacity: 10, remaining_slots: 10, venue_profiles: { venue_name: "Demo Venue" } },
        ] as OfferRow[]);

  const displayBookings =
    mode === "live" && bookings.length > 0
      ? bookings
      : ([
          { id: "b1", stage: "confirmed", proof_status: "pending", offers: { title: "Rooftop opening night", venue_profiles: { venue_name: "Demo Venue" } } },
        ] as BookingRow[]);

  return (
    <MarviScreen>
      <div className="mx-auto max-w-6xl px-4 py-10 md:px-6 md:py-12">
        <PageHeader
          eyebrow={d.eyebrow}
          title={d.title}
          subtitle={
            mode === "live" && userEmail
              ? tReplace(d.signedInAs, { email: userEmail })
              : d.previewSubtitle
          }
          action={
            <Link href="/portal/campaigns/new" className="marvi-btn-primary">
              {d.newCampaign}
            </Link>
          }
        />

        {mode === "preview" ? (
          <div className="mt-6">
            <SyncBanner
              tone="info"
              message={d.previewBanner}
              action={
                <Link href="/portal/login" className="marvi-btn-secondary text-xs">
                  {c.signIn}
                </Link>
              }
            />
          </div>
        ) : null}

        <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {metrics.map((m) => (
            <MetricTile key={m.label} icon={m.icon} value={m.value} label={m.label} hint={m.hint} tone={m.tone} />
          ))}
        </div>

        <div className="mt-10">
          <h2 className="text-xs font-bold uppercase tracking-[0.14em] text-muted">{d.studioStatus}</h2>
          <div className="mt-3">
            <StudioStatusGrid items={studioGrid} />
          </div>
        </div>

        <div className="mt-10 grid gap-6 lg:grid-cols-2">
          <section className="marvi-card">
            <div className="flex items-center justify-between gap-3">
              <h2 className="font-bold text-ink">{d.campaigns}</h2>
              <Link href="/portal/campaigns/new" className="text-xs font-bold text-rose">
                {d.newShort}
              </Link>
            </div>
            <div className="mt-4 space-y-2">
              {displayOffers.map((offer) => {
                const filled = offer.capacity - offer.remaining_slots;
                return (
                  <ListRow
                    key={offer.id}
                    title={offer.title}
                    subtitle={`${venueName(offer.venue_profiles, c.venue)} · ${tReplace(d.slotsFilled, { filled, capacity: offer.capacity })}`}
                    badge={<StatusPill label={formatStatusLabel(offer.status, locale)} tone={offerStatusTone(offer.status)} />}
                    trailing={
                      offer.status === "live" ? (
                        <Link href={`/portal/creators?offerId=${offer.id}`} className="text-xs font-bold text-rose">
                          {d.match}
                        </Link>
                      ) : null
                    }
                  />
                );
              })}
            </div>
          </section>

          <section className="marvi-card">
            <div className="flex items-center justify-between gap-3">
              <h2 className="font-bold text-ink">{d.bookingsProof}</h2>
              <Link href="/portal/reviews" className="text-xs font-bold text-rose">
                {d.reviewQueueLink}
              </Link>
            </div>
            <div className="mt-4 space-y-2">
              {displayBookings.length === 0 ? (
                <EmptyState
                  icon={<IconCalendar size={24} />}
                  title={d.noBookingsTitle}
                  body={d.noBookingsBody}
                />
              ) : (
                displayBookings.map((booking) => (
                  <ListRow
                    key={booking.id}
                    title={booking.offers?.title ?? c.booking}
                    subtitle={venueName(booking.offers?.venue_profiles ?? null, c.venue)}
                    meta={`${c.stage}: ${formatStatusLabel(booking.stage, locale)}`}
                    badge={
                      <StatusPill
                        label={`${c.proof} ${formatStatusLabel(booking.proof_status, locale)}`}
                        tone={proofStatusTone(booking.proof_status)}
                      />
                    }
                  />
                ))
              )}
            </div>
          </section>
        </div>

        <div className="mt-8 flex flex-wrap gap-3">
          <Link href="/portal/creators" className="marvi-btn-secondary">
            {d.creatorMatching}
          </Link>
          <Link href="/portal/reviews" className="marvi-btn-secondary">
            {d.reviewQueue}
          </Link>
        </div>
      </div>
    </MarviScreen>
  );
}
