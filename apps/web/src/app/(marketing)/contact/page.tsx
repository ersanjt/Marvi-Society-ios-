import { SectionHeading } from "@/components/marketing/SectionHeading";
import { SITE } from "@/lib/constants";

export const metadata = { title: "Contact" };

export default async function ContactPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const showConfigError = params.error === "configuration";

  return (
    <div className="mx-auto max-w-2xl px-4 py-16 md:px-6 md:py-24">
      <SectionHeading title="Contact support" subtitle="Account help, campaigns, safety reports, and partnership inquiries." />

      {showConfigError && (
        <div className="mt-8 rounded-marvi border border-rose/30 bg-rose/10 px-4 py-3 text-sm text-ink">
          The venue portal is temporarily unavailable because Supabase is not configured in production.
          Please contact support while we restore access.
        </div>
      )}

      <div className="mt-10 space-y-4">
        <div className="marvi-card">
          <h3 className="font-bold">General support</h3>
          <p className="mt-2 text-sm text-muted">Questions about your account, bookings, or platform access.</p>
          <a href={`mailto:${SITE.supportEmail}`} className="mt-3 inline-block text-sm marvi-link">
            {SITE.supportEmail}
          </a>
        </div>
        <div className="marvi-card">
          <h3 className="font-bold">Safety & moderation</h3>
          <p className="mt-2 text-sm text-muted">Report abusive behavior or urgent trust issues.</p>
          <a href={`mailto:${SITE.supportEmail}?subject=Safety%20report`} className="mt-3 inline-block text-sm marvi-link">
            Report an issue
          </a>
        </div>
      </div>
    </div>
  );
}
