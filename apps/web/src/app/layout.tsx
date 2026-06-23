import type { Metadata } from "next";
import { SITE } from "@/config/site";
import { getLocale } from "@/lib/i18n/locale";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: SITE.name,
    template: `%s · ${SITE.name}`,
  },
  description: SITE.description,
  metadataBase: new URL(SITE.url),
  icons: {
    icon: "/favicon.svg",
    apple: "/logo.svg",
  },
  openGraph: {
    title: SITE.name,
    description: SITE.description,
    siteName: SITE.name,
    type: "website",
    url: SITE.url,
    images: [{ url: "/logo.svg", width: 48, height: 48, alt: SITE.name }],
  },
  alternates: {
    languages: {
      en: "/",
      tr: "/",
    },
  },
};

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const locale = await getLocale();

  return (
    <html lang={locale}>
      <body>{children}</body>
    </html>
  );
}
