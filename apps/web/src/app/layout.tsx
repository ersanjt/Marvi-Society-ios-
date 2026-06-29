import type { Metadata } from "next";
import { SITE } from "@/config/site";
import { getLocale } from "@/lib/i18n/locale";
import { RecoveryRedirectGuard } from "@/components/auth/RecoveryRedirectGuard";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: SITE.name,
    template: `%s · ${SITE.name}`,
  },
  description: SITE.description,
  metadataBase: new URL(SITE.url),
  icons: {
    icon: "/app-icon.png",
    apple: "/app-icon.png",
  },
  openGraph: {
    title: SITE.name,
    description: SITE.description,
    siteName: SITE.name,
    type: "website",
    url: SITE.url,
    images: [
      {
        url: "/screenshots/iphone/marvi-01-kesfet.png",
        width: 1284,
        height: 2778,
        alt: `${SITE.name} — Explore`,
      },
    ],
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
      <body>
        <RecoveryRedirectGuard />
        {children}
      </body>
    </html>
  );
}
