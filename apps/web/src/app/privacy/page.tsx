import { SectionHeading } from "@/components/marketing/SectionHeading";

export const metadata = { title: "Privacy Policy" };

export default function PrivacyPage() {
  return (
    <div className="mx-auto max-w-3xl px-4 py-16 md:px-6 md:py-24">
      <SectionHeading title="Privacy Policy" subtitle="Last updated: June 2026" />
      <div className="prose prose-sm mt-10 max-w-none text-muted">
        <p>Marvi Society collects account information, location (for nearby offers), social handles, proof links, and usage data to operate the collaboration marketplace.</p>
        <p>Data is processed under applicable laws including KVKK (Turkey) and GDPR where applicable. Contact support@marvisociety.com for data requests.</p>
        <p>Full legal document will be published before public App Store launch.</p>
      </div>
    </div>
  );
}
