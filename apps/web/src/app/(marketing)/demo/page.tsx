import { DemoForm } from "@/components/marketing/DemoForm";
import { SectionHeading } from "@/components/marketing/SectionHeading";
import { MarviScreen } from "@/components/design/MarviUI";
import Link from "next/link";

export const metadata = { title: "Get demo" };

export default function DemoPage() {
  return (
    <MarviScreen>
      <div className="mx-auto max-w-2xl px-4 py-16 md:px-6 md:py-24">
        <SectionHeading
          eyebrow="Demo"
          title="See Marvi Society in action"
          subtitle="For brands and venues. Creators should apply via the iOS app."
        />

        <div className="marvi-card mt-10 border-gold/30 bg-gold/5">
          <p className="text-sm font-semibold leading-relaxed text-graphite">
            Are you a creator? This form is for brand partners.{" "}
            <Link href="/creators" className="marvi-link">
              Download the iOS app
            </Link>{" "}
            to apply for membership.
          </p>
        </div>

        <DemoForm />
      </div>
    </MarviScreen>
  );
}
