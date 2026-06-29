import { DeleteAccountForm } from "@/components/marketing/DeleteAccountForm";
import { SectionHeading } from "@/components/marketing/SectionHeading";
import { SITE } from "@/lib/constants";
import { getI18n } from "@/lib/i18n/locale";

export const metadata = { title: "Delete account" };

export default async function DeleteAccountPage() {
  const { dict } = await getI18n();
  const t = dict.forms.deleteAccount;

  return (
    <div className="mx-auto max-w-xl px-4 py-16 md:px-6 md:py-24">
      <SectionHeading title={t.title} subtitle={t.subtitle} />

      <div className="marvi-card mt-10 space-y-3">
        <h2 className="font-serif text-lg font-bold text-ink">{t.pauseTitle}</h2>
        <p className="text-sm text-muted">{t.pauseBody}</p>
        <p className="text-xs text-muted">
          {t.pauseHelp}{" "}
          <a href={`mailto:${SITE.supportEmail}`} className="marvi-link">
            {SITE.supportEmail}
          </a>
          .
        </p>
      </div>

      <SectionHeading eyebrow={t.permanentEyebrow} title={t.permanentTitle} subtitle={t.permanentSubtitle} />
      <DeleteAccountForm supportEmail={SITE.supportEmail} t={t} />
    </div>
  );
}
