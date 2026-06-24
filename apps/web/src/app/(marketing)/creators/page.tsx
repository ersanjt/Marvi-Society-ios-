import Link from "next/link";
import Image from "next/image";
import { PhoneFrame } from "@/components/marketing/AppScreenshot";
import { SectionHeading } from "@/components/marketing/SectionHeading";
import { CollaborationModelCard } from "@/components/marketing/CollaborationModelCard";
import { MarviScreen, MetricTile } from "@/components/design/MarviUI";
import { COLLABORATION_MODELS, SITE } from "@/lib/constants";
import { getI18n } from "@/lib/i18n/locale";

export const metadata = { title: "Creators" };

const CREATOR_BENEFITS = [
  {
    title: "Instant",
    titleTr: "Anlık",
    desc: "Skip the wait. Open the map, accept a nearby offer, visit, and post.",
    descTr: "Beklemeyin. Haritayı açın, yakındaki teklifi kabul edin, ziyaret edin ve paylaşın.",
    tone: "rose" as const,
  },
  {
    title: "Invitations",
    titleTr: "Davetler",
    desc: "Apply to curated venue experiences with clear deliverables and slots.",
    descTr: "Net teslimatlar ve slotlarla seçilmiş mekan deneyimlerine başvurun.",
    tone: "aubergine" as const,
  },
  {
    title: "Events",
    titleTr: "Etkinlikler",
    desc: "RSVP to openings, rooftop nights, and private brand moments.",
    descTr: "Açılışlara, rooftop gecelerine ve özel marka anlarına RSVP verin.",
    tone: "gold" as const,
  },
  {
    title: "Gifts",
    titleTr: "Hediyeler",
    desc: "Receive products at your door and create authentic unboxing content.",
    descTr: "Ürünleri kapınıza alın ve özgün unboxing içeriği üretin.",
    tone: "emerald" as const,
  },
];

export default async function CreatorsPage() {
  const { dict, locale } = await getI18n();
  const isTr = locale === "tr";

  return (
    <>
      <MarviScreen className="border-b border-border">
        <div className="mx-auto grid max-w-6xl items-center gap-12 px-4 py-16 md:grid-cols-2 md:px-6 md:py-20">
          <div>
            <SectionHeading
              eyebrow={dict.creators.eyebrow}
              title={dict.creators.title}
              subtitle={dict.creators.subtitle}
            />
            <div className="mt-8 flex flex-wrap gap-3">
              <a href={SITE.appStoreUrl} className="marvi-btn-primary">
                {dict.creators.appStore}
              </a>
              <Link href="/faq" className="marvi-btn-secondary">
                {dict.creators.faq}
              </Link>
            </div>
          </div>
          <PhoneFrame
            src="/screenshots/iphone/marvi-02-profil-creator.png"
            alt={isTr ? "Profil ekranı" : "Profile screen"}
            priority
          />
        </div>
      </MarviScreen>

      <div className="mx-auto max-w-6xl px-4 py-16 md:px-6 md:py-20">
        <div className="grid gap-4 md:grid-cols-2">
          {CREATOR_BENEFITS.map((item, index) => (
            <MetricTile
              key={item.title}
              icon={<span className="text-xs font-bold">{String(index + 1).padStart(2, "0")}</span>}
              value={isTr ? item.titleTr : item.title}
              label={isTr ? item.descTr : item.desc}
              tone={item.tone}
            />
          ))}
        </div>

        <div className="mt-16 grid gap-10 lg:grid-cols-2">
          <div>
            <h3 className="font-serif text-2xl font-bold text-ink">
              {isTr ? "Uygulama ekranları" : "App screens"}
            </h3>
            <div className="mt-6 grid grid-cols-2 gap-3">
              {[
                "/screenshots/iphone/marvi-01-kesfet.png",
                "/screenshots/iphone/marvi-03-etkinliklerim.png",
                "/screenshots/iphone/marvi-04-sosyal-hesaplar.png",
                "/screenshots/iphone/marvi-05-yasal-hesap.png",
              ].map((src) => (
                <div key={src} className="overflow-hidden rounded-marvi-lg border border-border">
                  <Image src={src} alt="" width={640} height={1386} className="h-auto w-full" />
                </div>
              ))}
            </div>
          </div>

          <div className="marvi-card bg-brand-gradient-vertical p-8 text-white">
            <div className="flex items-center gap-3">
              <Image src="/app-icon.png" alt="" width={56} height={56} className="rounded-marvi-lg" />
              <div>
                <p className="text-xs font-bold uppercase tracking-[0.14em] text-gold">iOS</p>
                <h3 className="font-serif text-2xl font-bold">{dict.creators.joinTitle}</h3>
              </div>
            </div>
            <p className="mt-4 text-sm leading-relaxed text-white/85">{dict.creators.joinBody}</p>
            <div className="mt-6 flex flex-wrap gap-3">
              <a href={SITE.appStoreUrl} className="marvi-btn-secondary">
                {dict.creators.appStore}
              </a>
              <Link
                href="/faq"
                className="inline-flex items-center rounded-marvi border border-white/30 px-5 py-3 text-sm font-bold text-white transition hover:bg-white/10"
              >
                {dict.creators.faq}
              </Link>
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
