import Link from "next/link";
import { AppShowcase } from "@/components/marketing/AppShowcase";
import { CollaborationModelCard } from "@/components/marketing/CollaborationModelCard";
import { PhoneFrame } from "@/components/marketing/AppScreenshot";
import { SectionHeading } from "@/components/marketing/SectionHeading";
import { IconBuilding, IconCalendar, IconShield, IconSparkles } from "@/components/design/MarviIcons";
import { MarviScreen, MetricTile } from "@/components/design/MarviUI";
import { COLLABORATION_MODELS } from "@/lib/constants";
import { getI18n } from "@/lib/i18n/locale";

export default async function HomePage() {
  const { dict, locale } = await getI18n();

  return (
    <>
      <MarviScreen className="border-b border-border">
        <div className="mx-auto grid max-w-6xl items-center gap-12 px-4 py-16 md:grid-cols-2 md:px-6 md:py-24">
          <div>
            <p className="marvi-eyebrow">{dict.hero.eyebrow}</p>
            <h1 className="mt-4 font-serif text-4xl font-bold leading-[1.1] text-ink md:text-5xl lg:text-[3.25rem]">
              {dict.hero.title}
            </h1>
            <p className="mt-5 max-w-lg text-lg leading-relaxed text-muted">{dict.hero.subtitle}</p>
            <div className="mt-8 flex flex-wrap gap-3">
              <Link href="/creators" className="marvi-btn-primary">
                {dict.hero.ctaCreators}
              </Link>
              <Link href="/brands" className="marvi-btn-secondary">
                {dict.hero.ctaBrands}
              </Link>
            </div>
            <div className="mt-10 grid grid-cols-3 gap-3">
              <MetricTile
                icon={<IconBuilding size={18} />}
                value="42+"
                label={dict.hero.statVenues}
                tone="aubergine"
              />
              <MetricTile
                icon={<IconSparkles size={18} />}
                value="128"
                label={dict.hero.statCreators}
                tone="rose"
              />
              <MetricTile
                icon={<IconCalendar size={18} />}
                value="96%"
                label={dict.hero.statProof}
                tone="emerald"
              />
            </div>
          </div>

          <PhoneFrame
            src="/screenshots/iphone/marvi-01-kesfet.png"
            alt={locale === "tr" ? "Keşfet ekranı" : "Explore screen"}
            priority
            className="md:justify-self-end"
          />
        </div>
      </MarviScreen>

      <section className="mx-auto max-w-6xl px-4 py-20 md:px-6">
        <SectionHeading
          eyebrow={dict.showcase.eyebrow}
          title={dict.showcase.title}
          subtitle={dict.showcase.subtitle}
        />
        <div className="mt-12">
          <AppShowcase locale={locale} />
        </div>
      </section>

      <section className="border-y border-border bg-surface-cool">
        <div className="mx-auto max-w-6xl px-4 py-20 md:px-6">
          <SectionHeading
            eyebrow={dict.models.eyebrow}
            title={dict.models.title}
            subtitle={dict.models.subtitle}
          />
          <div className="mt-10 grid gap-4 md:grid-cols-2">
            {COLLABORATION_MODELS.map((model) => (
              <CollaborationModelCard key={model.id} model={model} locale={locale} />
            ))}
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-6xl px-4 py-20 md:px-6">
        <SectionHeading
          eyebrow={dict.platform.eyebrow}
          title={dict.platform.title}
          subtitle={dict.platform.subtitle}
        />
        <div className="mt-10 grid gap-4 md:grid-cols-3">
          {[
            { title: locale === "tr" ? "Üreticiler" : "Creators", body: dict.platform.creators, href: "/creators", icon: <IconSparkles size={20} />, tone: "rose" as const },
            { title: locale === "tr" ? "Markalar" : "Brands", body: dict.platform.brands, href: "/brands", icon: <IconBuilding size={20} />, tone: "aubergine" as const },
            { title: locale === "tr" ? "Operatörler" : "Operators", body: dict.platform.operators, href: "/admin", icon: <IconShield size={20} />, tone: "gold" as const },
          ].map((card) => (
            <Link key={card.href} href={card.href} className="marvi-card group block transition hover:border-rose/30">
              <div className={`mb-4 flex h-11 w-11 items-center justify-center rounded-marvi bg-rose/15 text-rose group-hover:bg-brand-gradient group-hover:text-white ${card.tone === "aubergine" ? "bg-aubergine/15 text-aubergine" : ""} ${card.tone === "gold" ? "bg-gold/15 text-gold" : ""}`}>
                {card.icon}
              </div>
              <h3 className="font-bold text-ink">{card.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-muted">{card.body}</p>
            </Link>
          ))}
        </div>
      </section>

      <section className="border-t border-border bg-panel">
        <div className="mx-auto max-w-6xl px-4 py-20 text-center md:px-6">
          <h2 className="font-serif text-3xl font-bold text-ink md:text-4xl">{dict.cta.title}</h2>
          <p className="mx-auto mt-4 max-w-xl text-muted">{dict.cta.subtitle}</p>
          <div className="mt-8 flex flex-wrap justify-center gap-3">
            <Link href="/demo" className="marvi-btn-primary">
              {dict.cta.demo}
            </Link>
            <Link href="/faq" className="marvi-btn-secondary">
              {dict.cta.faq}
            </Link>
          </div>
        </div>
      </section>
    </>
  );
}
