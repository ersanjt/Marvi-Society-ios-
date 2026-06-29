import Image from "next/image";
import Link from "next/link";
import { BrandMark } from "@/components/brand/BrandMark";
import { SITE } from "@/lib/constants";
import { type Locale, getDictionary } from "@/lib/i18n/dictionaries";

export function Footer({ locale }: { locale: Locale }) {
  const dict = getDictionary(locale);

  return (
    <footer className="border-t border-border bg-panel">
      <div className="mx-auto grid max-w-6xl grid-cols-2 gap-8 px-4 py-12 sm:gap-10 md:grid-cols-4 md:px-6 md:py-14">
        <div className="col-span-2 md:col-span-2">
          <div className="flex items-center gap-3">
            <BrandMark size={44} />
            <p className="font-serif text-2xl font-bold text-ink">{SITE.name}</p>
          </div>
          <p className="mt-4 max-w-md text-sm leading-relaxed text-muted">{SITE.tagline}</p>
          <div className="mt-6 flex flex-wrap items-center gap-3">
            <a href={SITE.appStoreUrl} className="marvi-btn-secondary text-xs">
              App Store
            </a>
            <Image src="/app-icon.png" alt="" width={40} height={40} className="rounded-marvi" />
          </div>
        </div>

        <div>
          <p className="marvi-eyebrow text-gold">{dict.footer.product}</p>
          <ul className="mt-4 space-y-2 text-sm text-graphite">
            <li><Link href="/creators" className="transition hover:text-ink">{dict.footer.creators}</Link></li>
            <li><Link href="/brands" className="transition hover:text-ink">{dict.footer.brands}</Link></li>
            <li><Link href="/faq" className="transition hover:text-ink">{dict.footer.faq}</Link></li>
            <li><Link href="/demo" className="transition hover:text-ink">{dict.footer.demo}</Link></li>
          </ul>
        </div>

        <div>
          <p className="marvi-eyebrow text-gold">{dict.footer.legal}</p>
          <ul className="mt-4 space-y-2 text-sm text-graphite">
            <li><Link href="/privacy" className="transition hover:text-ink">{dict.footer.privacy}</Link></li>
            <li><Link href="/terms" className="transition hover:text-ink">{dict.footer.terms}</Link></li>
            <li><Link href="/community-guidelines" className="transition hover:text-ink">{dict.footer.guidelines}</Link></li>
            <li><Link href="/contact" className="transition hover:text-ink">{dict.footer.contact}</Link></li>
            <li><Link href="/delete-account" className="transition hover:text-ink">{dict.footer.deleteAccount}</Link></li>
          </ul>
        </div>
      </div>

      <div className="border-t border-border px-4 py-6 text-center text-xs text-muted md:px-6">
        © {new Date().getFullYear()} {SITE.name}. All rights reserved.
      </div>
    </footer>
  );
}
