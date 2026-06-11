import Link from "next/link";
import { SectionHeading } from "@/components/marketing/SectionHeading";
import { SITE } from "@/lib/constants";

export const metadata = { title: "Creators" };

const CREATOR_BENEFITS = [
  { title: "Instant", desc: "Skip the wait. Open the map, accept a nearby offer, visit, and post." },
  { title: "Invitations", desc: "Apply to curated venue experiences with clear deliverables and slots." },
  { title: "Events", desc: "RSVP to openings, rooftop nights, and private brand moments." },
  { title: "Gifts", desc: "Receive products at your door and create authentic unboxing content." },
];

export default function CreatorsPage() {
  return (
    <div className="mx-auto max-w-6xl px-4 py-16 md:px-6 md:py-24">
      <SectionHeading
        eyebrow="Creators"
        title="Exclusive experiences. Structured workflow. No agency emails."
        subtitle="Download the iOS app, apply for membership, and start collaborating with Istanbul's curated venue network."
      />

      <div className="mt-12 grid gap-4 md:grid-cols-2">
        {CREATOR_BENEFITS.map((item, index) => (
          <article key={item.title} className="marvi-card">
            <p className="text-xs font-bold text-gold">0{index + 1}</p>
            <h3 className="mt-2 text-xl font-bold text-ink">{item.title}</h3>
            <p className="mt-2 text-sm text-muted">{item.desc}</p>
          </article>
        ))}
      </div>

      <div className="marvi-card mt-12 bg-emerald text-white">
        <h3 className="font-serif text-2xl font-bold">Join the creator community</h3>
        <p className="mt-3 max-w-2xl text-sm text-white/85">
          Requirements: independent creator account, original content, typically 5,000+ followers. Applications reviewed by {SITE.name} operators.
        </p>
        <div className="mt-6 flex flex-wrap gap-3">
          <a href={SITE.appStoreUrl} className="marvi-btn-secondary !text-ink">
            Download on App Store
          </a>
          <Link href="/faq" className="inline-flex items-center rounded-marvi border border-white/30 px-5 py-3 text-sm font-bold text-white hover:bg-white/10">
            Application FAQ
          </Link>
        </div>
      </div>
    </div>
  );
}
