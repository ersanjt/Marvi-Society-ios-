import Link from "next/link";
import { SectionHeading } from "@/components/marketing/SectionHeading";
import { COLLABORATION_MODELS, SITE } from "@/lib/constants";
import { getI18n } from "@/lib/i18n/locale";

export default async function HomePage() {
  const { dict } = await getI18n();
  return (
    <>
      <section className="relative overflow-hidden border-b border-black/5">
        <div className="absolute inset-0 bg-gradient-to-br from-emerald/10 via-surface to-gold/10" />
        <div className="relative mx-auto grid max-w-6xl gap-12 px-4 py-20 md:grid-cols-2 md:px-6 md:py-28">
          <div>
            <p className="text-xs font-bold uppercase tracking-widest text-emerald">
              {dict.hero.eyebrow}
            </p>
            <h1 className="mt-4 font-serif text-4xl font-bold leading-tight text-ink md:text-5xl">
              {dict.hero.title}
            </h1>
            <p className="mt-5 max-w-lg text-lg text-muted">
              {SITE.description} Structured invitations, real-time map offers, and proof workflows — built for operators who care about quality.
            </p>
            <div className="mt-8 flex flex-wrap gap-3">
              <Link href="/creators" className="marvi-btn-primary">
                {dict.hero.ctaCreators}
              </Link>
              <Link href="/brands" className="marvi-btn-secondary">
                {dict.hero.ctaBrands}
              </Link>
            </div>
            <div className="mt-10 grid grid-cols-3 gap-3">
              {[
                { value: "42+", label: "Venues" },
                { value: "128", label: "Creators" },
                { value: "96%", label: "Proof rate" },
              ].map((stat) => (
                <div key={stat.label} className="marvi-card py-4 text-center">
                  <p className="text-2xl font-bold text-emerald">{stat.value}</p>
                  <p className="text-xs font-semibold text-muted">{stat.label}</p>
                </div>
              ))}
            </div>
          </div>

          <div className="marvi-card bg-gradient-to-br from-ink to-aubergine p-8 text-white">
            <p className="text-xs font-bold uppercase tracking-widest text-gold">Creator app preview</p>
            <h2 className="mt-3 font-serif text-3xl font-bold">Discover · Nearby · Proof</h2>
            <ul className="mt-6 space-y-4 text-sm text-white/85">
              <li className="flex gap-3">
                <span className="text-gold">01</span>
                Browse curated Istanbul invitations by category and model
              </li>
              <li className="flex gap-3">
                <span className="text-gold">02</span>
                Open the map for instant café and walk-in offers nearby
              </li>
              <li className="flex gap-3">
                <span className="text-gold">03</span>
                Check in, post content, submit proof links — done
              </li>
            </ul>
            <Link href="/demo" className="marvi-btn-primary mt-8 w-full">
              Request brand demo
            </Link>
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-6xl px-4 py-20 md:px-6">
        <SectionHeading
          eyebrow="Collaboration models"
          title="Four ways to partner — you choose the model"
          subtitle="Parity with leading platforms. Invitation, events, gifting, and instant walk-in experiences."
        />
        <div className="mt-10 grid gap-4 md:grid-cols-2">
          {COLLABORATION_MODELS.map((model) => (
            <article key={model.id} className="marvi-card">
              <div className="flex items-start gap-4">
                <span className="text-2xl">{model.icon}</span>
                <div>
                  <h3 className="text-lg font-bold text-ink">{model.title}</h3>
                  <p className="mt-2 text-sm text-muted">{model.description}</p>
                </div>
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className="border-y border-black/5 bg-cool">
        <div className="mx-auto max-w-6xl px-4 py-20 md:px-6">
          <SectionHeading
            eyebrow="Global-ready architecture"
            title="iOS today. Android and web portal next."
            subtitle="One API contract, Supabase backend, admin review queues, and venue analytics."
          />
          <div className="mt-10 grid gap-4 md:grid-cols-3">
            {[
              { title: "Creators", body: "Native iOS app with Discover, map, bookings, and proof submission.", href: "/creators" },
              { title: "Brands", body: "Web portal for campaign builder, bookings list, and performance metrics.", href: "/brands" },
              { title: "Operators", body: "Admin console for applications, campaigns, proof review, and strikes.", href: "/admin" },
            ].map((card) => (
              <Link key={card.title} href={card.href} className="marvi-card transition hover:border-emerald/30">
                <h3 className="font-bold text-ink">{card.title}</h3>
                <p className="mt-2 text-sm text-muted">{card.body}</p>
              </Link>
            ))}
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-6xl px-4 py-20 text-center md:px-6">
        <h2 className="font-serif text-3xl font-bold text-ink">Ready to launch in Istanbul?</h2>
        <p className="mx-auto mt-4 max-w-xl text-muted">
          Join the private club connecting creators and venues with structured content delivery.
        </p>
        <div className="mt-8 flex flex-wrap justify-center gap-3">
          <Link href="/demo" className="marvi-btn-primary">Book a demo</Link>
          <Link href="/faq" className="marvi-btn-secondary">Read FAQ</Link>
        </div>
      </section>
    </>
  );
}
