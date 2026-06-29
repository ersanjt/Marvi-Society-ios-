import { SectionHeading } from "@/components/marketing/SectionHeading";
import { ContactForm } from "@/components/marketing/ContactForm";
import { MarviScreen } from "@/components/design/MarviUI";
import { SITE } from "@/lib/constants";
import { getI18n } from "@/lib/i18n/locale";

export const metadata = { title: "Contact" };

export default async function ContactPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const showConfigError = params.error === "configuration";
  const { dict } = await getI18n();
  const t = dict.forms.contact;

  return (
    <MarviScreen>
      <div className="mx-auto max-w-2xl px-4 py-16 md:px-6 md:py-24">
        <SectionHeading title={t.title} subtitle={t.subtitle} />

        {showConfigError && (
          <div className="mt-8 rounded-marvi border border-rose/30 bg-rose/10 px-4 py-3 text-sm text-ink">
            {t.configError}
          </div>
        )}

        <ContactForm supportEmail={SITE.supportEmail} t={t} />

        <div className="mt-8 space-y-4">
          <div className="marvi-card">
            <h3 className="font-bold text-ink">{t.safetyTitle}</h3>
            <p className="mt-2 text-sm text-muted">{t.safetyBody}</p>
            <a
              href={`mailto:${SITE.supportEmail}?subject=Safety%20report`}
              className="mt-3 inline-block text-sm marvi-link"
            >
              {t.safetyCta}
            </a>
          </div>
        </div>
      </div>
    </MarviScreen>
  );
}
