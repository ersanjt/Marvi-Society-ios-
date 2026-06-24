import { CampaignForm } from "@/components/portal/CampaignForm";
import { MarviScreen, PageHeader } from "@/components/design/MarviUI";
import { getI18n } from "@/lib/i18n/locale";
import { getPortalAdminDict } from "@/lib/i18n/portal-admin";
import Link from "next/link";

export async function generateMetadata() {
  const { locale } = await getI18n();
  return { title: getPortalAdminDict(locale).portal.campaign.metaTitle };
}

export default async function NewCampaignPage() {
  const { locale } = await getI18n();
  const dict = getPortalAdminDict(locale);
  const c = dict.portal.campaign;

  return (
    <MarviScreen>
      <div className="mx-auto max-w-2xl px-4 py-10 md:px-6 md:py-12">
        <Link href="/portal/dashboard" className="text-sm font-semibold text-rose transition hover:text-rose/80">
          {c.back}
        </Link>
        <div className="mt-4">
          <PageHeader eyebrow={c.eyebrow} title={c.title} subtitle={c.subtitle} />
        </div>
        <CampaignForm dict={dict} />
      </div>
    </MarviScreen>
  );
}
