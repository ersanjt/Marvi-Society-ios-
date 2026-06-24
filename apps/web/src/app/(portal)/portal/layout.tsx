import { PortalChrome } from "@/components/portal/PortalChrome";
import { PortalNav } from "@/components/portal/PortalNav";
import { VenueSwitcher } from "@/components/portal/VenueSwitcher";
import { getI18n } from "@/lib/i18n/locale";
import { getPortalAdminDict } from "@/lib/i18n/portal-admin";

export default async function PortalLayout({ children }: { children: React.ReactNode }) {
  const { locale } = await getI18n();
  const dict = getPortalAdminDict(locale);

  return (
    <PortalChrome
      chrome={
        <>
          <PortalNav dict={dict} locale={locale} />
          <VenueSwitcher dict={dict} />
        </>
      }
    >
      {children}
    </PortalChrome>
  );
}
