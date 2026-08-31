import Link from "next/link";
import { redirect } from "next/navigation";
import { BillingPortalButton, CheckoutButton } from "@/components/billing/CheckoutButton";
import { EmptyState, MarviScreen, PageHeader, StatusPill, SyncBanner } from "@/components/design/MarviUI";
import { IconSparkles } from "@/components/design/MarviIcons";
import { BILLING, formatUsd } from "@/lib/billing/plans";
import { isStripeConfigured, isSupabaseConfigured } from "@/config/env";
import { getI18n } from "@/lib/i18n/locale";
import { getPortalAdminDict } from "@/lib/i18n/portal-admin";
import { createClient } from "@/lib/supabase/server";

export async function generateMetadata() {
  const { locale } = await getI18n();
  return { title: getPortalAdminDict(locale).portal.billing.metaTitle };
}

type BillingStatus = {
  venue_id?: string;
  plan?: string;
  partner?: boolean;
  live_campaigns?: number;
  live_campaign_limit?: number | null;
  subscription_status?: string | null;
  current_period_end?: string | null;
};

type OfferRow = {
  id: string;
  title: string;
  status: string;
  featured_until: string | null;
  deleted_at: string | null;
};

export default async function PortalBillingPage({
  searchParams,
}: {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
}) {
  const { locale } = await getI18n();
  const dict = getPortalAdminDict(locale);
  const b = dict.portal.billing;
  const params = searchParams ? await searchParams : {};
  const stripeReady = isStripeConfigured();

  if (!isSupabaseConfigured()) {
    redirect("/portal/login?next=/portal/billing");
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    redirect("/portal/login?next=/portal/billing");
  }

  const { data: billingRaw } = await supabase.rpc("venue_billing_status");
  const billing = (billingRaw ?? {}) as BillingStatus;
  const partner = Boolean(billing.partner);
  const planLabel = partner ? BILLING.partner.name : BILLING.free.name;

  const { data: offersRaw } = await supabase
    .from("offers")
    .select("id, title, status, featured_until, deleted_at")
    .eq("status", "live")
    .is("deleted_at", null)
    .order("created_at", { ascending: false })
    .limit(20);
  const offers = (offersRaw ?? []) as OfferRow[];

  const boostOffer =
    typeof params.boost === "string" && params.boost !== "success" && params.boost !== "cancel"
      ? params.boost
      : null;

  const notice =
    params.plan === "success"
      ? b.partnerSuccess
      : params.boost === "success"
        ? b.boostSuccess
        : params.plan === "cancel" || params.boost === "cancel"
          ? b.checkoutCancel
          : null;

  return (
    <MarviScreen>
      <div className="mx-auto max-w-4xl px-4 py-10 md:px-6 md:py-12">
        <PageHeader eyebrow={b.eyebrow} title={b.title} subtitle={b.subtitle} />

        {notice ? (
          <div className="mt-6">
            <SyncBanner tone="success" message={notice} />
          </div>
        ) : null}

        <div className="mt-8 grid gap-4 md:grid-cols-2">
          <div className="marvi-card space-y-3">
            <div className="flex items-center justify-between gap-3">
              <h2 className="font-serif text-2xl font-bold">{planLabel}</h2>
              <StatusPill label={partner ? b.partner : b.free} tone={partner ? "emerald" : "muted"} />
            </div>
            <p className="text-sm text-muted">
              {partner
                ? b.partnerHint
                : `${b.freeHint} (${billing.live_campaigns ?? 0}/${billing.live_campaign_limit ?? 1})`}
            </p>
            {billing.current_period_end ? (
              <p className="text-xs text-muted">
                {b.renews} {new Date(billing.current_period_end).toLocaleDateString(locale === "tr" ? "tr-TR" : "en-US")}
              </p>
            ) : null}
            {stripeReady ? (
              partner ? (
                <BillingPortalButton label={b.manageBilling} />
              ) : (
                <CheckoutButton kind="partner" label={`${b.upgrade} · ${formatUsd(BILLING.partner.amountCents)}/${locale === "tr" ? "ay" : "mo"}`} />
              )
            ) : (
              <Link href="/demo" className="marvi-btn-secondary inline-flex">
                {b.requestBilling}
              </Link>
            )}
          </div>

          <div className="marvi-card space-y-3">
            <h2 className="font-serif text-2xl font-bold">{b.boostTitle}</h2>
            <p className="text-sm text-muted">
              {b.boostBody} {formatUsd(BILLING.boost.amountCents)} / {BILLING.boost.days} {b.days}.
            </p>
            <Link href="/pricing" className="text-sm font-semibold text-rose">
              {b.seePricing}
            </Link>
          </div>
        </div>

        <section className="mt-10">
          <h3 className="font-serif text-xl font-bold">{b.liveCampaigns}</h3>
          {offers.length === 0 ? (
            <div className="mt-4">
              <EmptyState icon={<IconSparkles size={24} />} title={b.noLiveTitle} body={b.noLiveBody} />
              <Link href="/portal/campaigns/new" className="marvi-btn-primary mt-4 inline-flex">
                {dict.portal.nav.newCampaign}
              </Link>
            </div>
          ) : (
            <ul className="mt-4 space-y-3">
              {offers.map((offer) => {
                const featured =
                  offer.featured_until && new Date(offer.featured_until).getTime() > Date.now();
                return (
                  <li key={offer.id} className="marvi-card flex flex-wrap items-center justify-between gap-3">
                    <div>
                      <p className="font-semibold">{offer.title}</p>
                      <p className="text-xs text-muted">
                        {featured
                          ? `${b.featuredUntil} ${new Date(offer.featured_until!).toLocaleString(locale === "tr" ? "tr-TR" : "en-US")}`
                          : b.notFeatured}
                      </p>
                    </div>
                    {stripeReady ? (
                      <CheckoutButton
                        kind="boost"
                        offerId={offer.id}
                        label={boostOffer === offer.id ? b.boostThis : b.boost}
                        className="marvi-btn-secondary"
                      />
                    ) : null}
                  </li>
                );
              })}
            </ul>
          )}
        </section>
      </div>
    </MarviScreen>
  );
}
