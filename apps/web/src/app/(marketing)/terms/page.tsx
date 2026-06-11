import { LegalDocument } from "@/components/marketing/LegalDocument";
import { SectionHeading } from "@/components/marketing/SectionHeading";
import { getLegalDocument } from "@/lib/legal/content";
import { getLocale } from "@/lib/i18n/locale";

export async function generateMetadata() {
  const locale = await getLocale();
  const doc = getLegalDocument("terms", locale);
  return { title: doc.title };
}

export default async function TermsPage() {
  const locale = await getLocale();
  const doc = getLegalDocument("terms", locale);

  return (
    <div className="mx-auto max-w-3xl px-4 py-16 md:px-6 md:py-24">
      <SectionHeading title={doc.title} subtitle={doc.subtitle} />
      <LegalDocument doc={doc} />
    </div>
  );
}
