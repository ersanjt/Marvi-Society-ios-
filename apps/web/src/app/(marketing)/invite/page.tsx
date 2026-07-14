import { InviteLandingClient } from "@/components/marketing/InviteLandingClient";
import { getI18n } from "@/lib/i18n/locale";

export const metadata = { title: "Open invite" };

type InvitePageProps = {
  searchParams?: Promise<{ code?: string; invite_code?: string }>;
};

export default async function InvitePage({ searchParams }: InvitePageProps) {
  const { dict, locale } = await getI18n();
  const params = (await searchParams) ?? {};
  const code = (params.code || params.invite_code || "").trim().toUpperCase();
  const isTr = locale === "tr";

  return (
    <InviteLandingClient
      code={code}
      title={isTr ? "Davetini uygulamada aç" : "Open your invite in the app"}
      subtitle={
        isTr
          ? "Marvi Society creator uygulamasında devam et. Uygulama yoksa App Store veya Google Play’den indir."
          : "Continue in the Marvi Society creator app. If you don’t have it yet, download from the App Store or Google Play."
      }
      openLabel={isTr ? "Uygulamada aç" : "Open in app"}
      codeLabel={isTr ? "Davet kodun" : "Your invite code"}
      appStoreLabel={dict.creators.appStore}
      playStoreLabel={dict.creators.playStore}
    />
  );
}
