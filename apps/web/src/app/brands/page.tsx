import Link from "next/link";
import { SectionHeading } from "@/components/marketing/SectionHeading";
import { COLLABORATION_MODELS } from "@/lib/constants";

export const metadata = { title: "Brands" };

export default function BrandsPage() {
  return (
    <div className="mx-auto max-w-6xl px-4 py-16 md:px-6 md:py-24">
      <SectionHeading
        eyebrow="Brands & venues"
        title="Connect with verified creators — effortlessly"
        subtitle="Publish offers, receive guaranteed Instagram and TikTok content, and track campaign performance from your portal."
      />

      <div className="mt-10 grid gap-6 md:grid-cols-3">
        {[
          "Access approved creator network in Istanbul",
          "Choose your collaboration model per campaign",
          "Admin-reviewed matching and proof collection",
        ].map((text) => (
          <div key={text} className="marvi-card text-sm font-semibold text-graphite">
            ✦ {text}
          </div>
        ))}
      </div>

      <h3 className="mt-16 font-serif text-2xl font-bold text-ink">Pick your collaboration model</h3>
      <div className="mt-6 grid gap-4 md:grid-cols-2">
        {COLLABORATION_MODELS.map((model, i) => (
          <article key={model.id} className="marvi-card">
            <p className="text-xs font-bold text-muted">MODEL {i + 1}</p>
            <h4 className="mt-2 text-lg font-bold">{model.title}</h4>
            <p className="mt-2 text-sm text-muted">{model.description}</p>
          </article>
        ))}
      </div>

      <div className="marvi-card mt-16 flex flex-col items-start justify-between gap-6 md:flex-row md:items-center">
        <div>
          <h3 className="font-serif text-2xl font-bold">Partner with Marvi Society</h3>
          <p className="mt-2 text-sm text-muted">F&B, beauty, nightlife, wellness, fitness, and retail.</p>
        </div>
        <div className="flex gap-3">
          <Link href="/demo" className="marvi-btn-primary">Get demo</Link>
          <Link href="/portal/login" className="marvi-btn-secondary">Brand login</Link>
        </div>
      </div>
    </div>
  );
}
