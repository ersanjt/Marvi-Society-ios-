import { Footer } from "@/components/marketing/Footer";
import { Header } from "@/components/marketing/Header";
import { getLocale } from "@/lib/i18n/locale";

export default async function MarketingLayout({ children }: { children: React.ReactNode }) {
  const locale = await getLocale();

  return (
    <>
      <Header locale={locale} />
      <main>{children}</main>
      <Footer locale={locale} />
    </>
  );
}
