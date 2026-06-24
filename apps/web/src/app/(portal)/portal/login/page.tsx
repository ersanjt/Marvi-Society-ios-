import { BrandLockup } from "@/components/brand/BrandMark";
import { LoginForm } from "@/components/portal/LoginForm";
import { MarviScreen } from "@/components/design/MarviUI";
import { LocaleSwitcher } from "@/components/marketing/LocaleSwitcher";
import { getI18n } from "@/lib/i18n/locale";
import { getPortalAdminDict } from "@/lib/i18n/portal-admin";
import Link from "next/link";
import { Suspense } from "react";

export async function generateMetadata() {
  const { locale } = await getI18n();
  const dict = getPortalAdminDict(locale);
  return { title: dict.portal.login.metaTitle };
}

export default async function PortalLoginPage() {
  const { locale } = await getI18n();
  const dict = getPortalAdminDict(locale);
  const p = dict.portal.login;
  const c = dict.common;

  return (
    <MarviScreen className="min-h-screen">
      <div className="mx-auto flex min-h-screen max-w-md flex-col justify-center px-4 py-16 md:px-6">
        <div className="mb-4 flex justify-end">
          <LocaleSwitcher current={locale} />
        </div>
        <div className="mb-8 flex justify-center">
          <BrandLockup subtitle={dict.portal.subtitle} size={52} />
        </div>
        <div className="marvi-card">
          <h1 className="font-serif text-2xl font-bold text-ink">{p.title}</h1>
          <p className="mt-2 text-sm text-muted">{p.description}</p>
          <Suspense fallback={<p className="mt-8 text-sm text-muted">{c.loading}</p>}>
            <LoginForm dict={dict} />
          </Suspense>
          <p className="mt-6 text-center text-xs text-muted">
            {p.noAccount}{" "}
            <Link href="/demo" className="marvi-link">
              {p.requestDemo}
            </Link>
          </p>
        </div>
        <p className="mt-8 text-center">
          <Link href="/" className="text-sm font-semibold text-graphite transition hover:text-rose">
            {p.backToSite}
          </Link>
        </p>
      </div>
    </MarviScreen>
  );
}
