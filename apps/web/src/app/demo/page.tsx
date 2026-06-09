import { SectionHeading } from "@/components/marketing/SectionHeading";
import { SITE } from "@/lib/constants";

export const metadata = { title: "Get demo" };

export default function DemoPage() {
  return (
    <div className="mx-auto max-w-2xl px-4 py-16 md:px-6 md:py-24">
      <SectionHeading
        eyebrow="Demo"
        title="See Marvi Society in action"
        subtitle="For brands and venues. Creators should apply via the iOS app."
      />

      <div className="marvi-card mt-10 border-gold/30 bg-gold/5">
        <p className="text-sm font-semibold text-graphite">
          👋 Are you a creator? This form is for brand partners. Download the app to apply for membership.
        </p>
      </div>

      <form className="marvi-card mt-6 space-y-4" action={`mailto:${SITE.email}`} method="GET">
        <div className="grid gap-4 md:grid-cols-2">
          <label className="block text-sm font-semibold">
            First name
            <input name="firstName" required className="mt-1 w-full rounded-marvi border border-black/10 px-3 py-2" />
          </label>
          <label className="block text-sm font-semibold">
            Last name
            <input name="lastName" required className="mt-1 w-full rounded-marvi border border-black/10 px-3 py-2" />
          </label>
        </div>
        <label className="block text-sm font-semibold">
          Company / venue
          <input name="company" required className="mt-1 w-full rounded-marvi border border-black/10 px-3 py-2" />
        </label>
        <label className="block text-sm font-semibold">
          Email
          <input type="email" name="email" required className="mt-1 w-full rounded-marvi border border-black/10 px-3 py-2" />
        </label>
        <label className="block text-sm font-semibold">
          Website
          <input type="url" name="website" className="mt-1 w-full rounded-marvi border border-black/10 px-3 py-2" />
        </label>
        <label className="block text-sm font-semibold">
          Message
          <textarea name="body" rows={4} className="mt-1 w-full rounded-marvi border border-black/10 px-3 py-2" placeholder="Tell us about your venue and campaign goals." />
        </label>
        <button type="submit" className="marvi-btn-primary w-full">
          Request demo
        </button>
      </form>
    </div>
  );
}
