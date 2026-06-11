import { SectionHeading } from "@/components/marketing/SectionHeading";
import { SITE } from "@/lib/constants";

export const metadata = { title: "Contact" };

export default function ContactPage() {
  return (
    <div className="mx-auto max-w-2xl px-4 py-16 md:px-6 md:py-24">
      <SectionHeading title="Contact support" subtitle="Account help, campaigns, safety reports, and partnership inquiries." />

      <div className="mt-10 space-y-4">
        <div className="marvi-card">
          <h3 className="font-bold">General support</h3>
          <p className="mt-2 text-sm text-muted">Questions about your account, bookings, or platform access.</p>
          <a href={`mailto:${SITE.supportEmail}`} className="mt-3 inline-block text-sm font-bold text-emerald">
            {SITE.supportEmail}
          </a>
        </div>
        <div className="marvi-card">
          <h3 className="font-bold">Safety & moderation</h3>
          <p className="mt-2 text-sm text-muted">Report abusive behavior or urgent trust issues.</p>
          <a href={`mailto:${SITE.supportEmail}?subject=Safety%20report`} className="mt-3 inline-block text-sm font-bold text-emerald">
            Report an issue
          </a>
        </div>
      </div>
    </div>
  );
}
