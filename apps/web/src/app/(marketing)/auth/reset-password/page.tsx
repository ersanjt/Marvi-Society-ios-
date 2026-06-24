import { BrandLockup } from "@/components/brand/BrandMark";
import { ResetPasswordForm } from "@/components/auth/ResetPasswordForm";
import { MarviScreen } from "@/components/design/MarviUI";
import { getLocale } from "@/lib/i18n/locale";
import Link from "next/link";

export const metadata = {
  title: "Reset password",
  robots: { index: false, follow: false },
};

export default async function ResetPasswordPage() {
  const locale = await getLocale();

  return (
    <MarviScreen className="min-h-screen">
      <div className="mx-auto flex min-h-screen max-w-md flex-col justify-center px-4 py-16 md:px-6">
        <div className="mb-8 flex justify-center">
          <BrandLockup subtitle={locale === "tr" ? "Şifre sıfırlama" : "Password reset"} size={52} />
        </div>
        <ResetPasswordForm locale={locale} />
        <p className="mt-8 text-center">
          <Link href="/" className="text-sm font-semibold text-graphite transition hover:text-rose">
            ← marvisociety.com
          </Link>
        </p>
      </div>
    </MarviScreen>
  );
}
