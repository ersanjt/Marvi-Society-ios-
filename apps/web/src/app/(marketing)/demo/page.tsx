import { DemoForm } from "@/components/marketing/DemoForm";
import { SectionHeading } from "@/components/marketing/SectionHeading";

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

      <DemoForm />
    </div>
  );
}
