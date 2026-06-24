import Link from "next/link";
import { PhoneFrame } from "@/components/marketing/AppScreenshot";
import { SectionHeading } from "@/components/marketing/SectionHeading";
import { CollaborationModelCard } from "@/components/marketing/CollaborationModelCard";
import { MarviScreen } from "@/components/design/MarviUI";
import { COLLABORATION_MODELS } from "@/lib/constants";
import { getI18n } from "@/lib/i18n/locale";

export const metadata = { title: "Brands" };

export default async function BrandsPage() {
  const { dict, locale } = await getI18n();
  const isTr = locale === "tr";

  return (
    <>
      <MarviScreen className="border-b border-border">
        <div className="mx-auto grid max-w-6xl items-center gap-12 px-4 py-16 md:grid-cols-2 md:px-6 md:py-20">
          <div>
            <SectionHeading
              eyebrow={dict.brands.eyebrow}
              title={dict.brands.title}
              subtitle={dict.brands.subtitle}
            />
            <div className="mt-8 flex flex-wrap gap-3">
              <Link href="/demo" className="marvi-btn-primary">
                {dict.brands.demo}
              </Link>
              <Link href="/portal/login" className="marvi-btn-secondary">
                {dict.brands.login}
              </Link>
            </div>
          </div>
          <PhoneFrame
            src="/screenshots/iphone/marvi-01-kesfet.png"
            alt={isTr ? "Keşfet ekranı" : "Explore screen"}
            priority
          />
        </div>
      </MarviScreen>

      <div className="mx-auto max-w-6xl px-4 py-16 md:px-6 md:py-20">
        <div className="grid gap-4 md:grid-cols-3">
          {dict.brands.benefits.map((text) => (
            <div key={text} className="marvi-card text-sm font-semibold leading-relaxed text-graphite">
              <span className="text-rose">✦</span> {text}
            </div>
          ))}
        </div>

        <h3 className="mt-16 font-serif text-2xl font-bold text-ink">{dict.brands.modelsTitle}</h3>
        <div className="mt-6 grid gap-4 md:grid-cols-2">
          {COLLABORATION_MODELS.map((model, i) => (
            <div key={model.id} className="relative">
              <p className="absolute -top-2 left-4 z-10 marvi-pill bg-panel-elevated text-[10px] text-muted">
                MODEL {i + 1}
              </p>
              <CollaborationModelCard model={model} locale={locale} />
            </div>
          ))}
        </div>

        <div className="marvi-card mt-16 flex flex-col items-start justify-between gap-6 md:flex-row md:items-center">
          <div>
            <h3 className="font-serif text-2xl font-bold">{dict.brands.partnerTitle}</h3>
            <p className="mt-2 text-sm text-muted">{dict.brands.partnerBody}</p>
          </div>
          <div className="flex flex-wrap gap-3">
            <Link href="/demo" className="marvi-btn-primary">
              {dict.brands.demo}
            </Link>
            <Link href="/portal/login" className="marvi-btn-secondary">
              {dict.brands.login}
            </Link>
          </div>
        </div>
      </div>
    </>
  );
}
