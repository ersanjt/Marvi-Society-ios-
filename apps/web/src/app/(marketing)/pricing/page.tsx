import Link from "next/link";
import { MarviScreen, PageHeader } from "@/components/design/MarviUI";
import { BILLING, formatUsd } from "@/lib/billing/plans";
import { getI18n } from "@/lib/i18n/locale";
import { isStripeConfigured } from "@/config/env";

export async function generateMetadata() {
  const { locale } = await getI18n();
  return { title: locale === "tr" ? "Fiyatlandırma" : "Pricing" };
}

export default async function PricingPage() {
  const { locale } = await getI18n();
  const tr = locale === "tr";
  const stripeReady = isStripeConfigured();

  return (
    <MarviScreen>
      <div className="mx-auto max-w-5xl px-4 py-16 md:px-6 md:py-24">
        <PageHeader
          eyebrow={tr ? "Mekânlar için" : "For venues"}
          title={tr ? "Creator ağına erişim — şeffaf fiyat" : "Access approved creators — clear venue pricing"}
          subtitle={
            tr
              ? "Creator’lar ücretsiz kalır. Mekânlar Explore’da yayınlamak ve öne çıkmak için Marvi’ye öder. Barter iş birliği aynı kalır."
              : "Creators stay free. Venues pay Marvi to publish and feature campaigns. The barter collaboration itself does not change."
          }
        />

        <div className="mt-12 grid gap-6 md:grid-cols-2">
          <div className="marvi-card space-y-4">
            <p className="marvi-eyebrow">{tr ? "Başlangıç" : "Start"}</p>
            <h2 className="font-serif text-3xl font-bold">{BILLING.free.name}</h2>
            <p className="text-3xl font-bold">{formatUsd(0)}</p>
            <ul className="space-y-2 text-sm text-graphite">
              <li>{tr ? "1 canlı kampanya" : "1 live campaign on Explore"}</li>
              <li>{tr ? "Kanıt ve check-in akışı" : "Check-in and proof workflow"}</li>
              <li>{tr ? "Creator eşleştirme" : "Creator matching"}</li>
            </ul>
            <Link href="/demo" className="marvi-btn-secondary inline-flex">
              {tr ? "Demo talep et" : "Request a demo"}
            </Link>
          </div>

          <div className="marvi-card space-y-4 border-rose/40">
            <p className="marvi-eyebrow text-rose">{tr ? "Büyüme" : "Grow"}</p>
            <h2 className="font-serif text-3xl font-bold">{BILLING.partner.name}</h2>
            <p className="text-3xl font-bold">
              {formatUsd(BILLING.partner.amountCents)}
              <span className="text-base font-semibold text-muted">/{tr ? "ay" : "mo"}</span>
            </p>
            <ul className="space-y-2 text-sm text-graphite">
              <li>{tr ? "Sınırsız canlı kampanya" : "Unlimited live campaigns"}</li>
              <li>{tr ? "Portal + mobil stüdyo" : "Portal and mobile Venue Studio"}</li>
              <li>
                {tr
                  ? `Featured Boost ayrı: ${formatUsd(BILLING.boost.amountCents)} / ${BILLING.boost.days} gün`
                  : `Featured Boost sold separately: ${formatUsd(BILLING.boost.amountCents)} / ${BILLING.boost.days} days`}
              </li>
            </ul>
            <Link href={stripeReady ? "/portal/billing" : "/demo"} className="marvi-btn-primary inline-flex">
              {stripeReady
                ? tr
                  ? "Portalda yükselt"
                  : "Upgrade in portal"
                : tr
                  ? "Demo ile başla"
                  : "Start with a demo"}
            </Link>
          </div>
        </div>

        <p className="mt-10 max-w-2xl text-sm text-muted">
          {tr
            ? "Creator’lardan uygulama içi ödeme alınmaz. Faturalama Stripe ile web portalında yapılır."
            : "We do not charge creators in-app. Venue billing runs on Stripe in the web portal."}
        </p>
      </div>
    </MarviScreen>
  );
}
