import { SectionHeading } from "@/components/marketing/SectionHeading";

export const metadata = { title: "Terms of Use" };

export default function TermsPage() {
  return (
    <div className="mx-auto max-w-3xl px-4 py-16 md:px-6 md:py-24">
      <SectionHeading title="Terms of Use" subtitle="Last updated: June 2026" />
      <div className="prose prose-sm mt-10 max-w-none text-muted">
        <p>By using Marvi Society you agree to our membership criteria, content delivery requirements, cancellation policy, and venue collaboration rules.</p>
        <p>Collaborations are barter-based. Creators receive complimentary experiences in exchange for agreed social content. Failure to deliver proof may affect membership status.</p>
        <p>Full terms will be published before public launch.</p>
      </div>
    </div>
  );
}
