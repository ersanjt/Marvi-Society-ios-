import { SITE } from "@/lib/constants";
import { type Locale, getDictionary } from "@/lib/i18n/dictionaries";
import Link from "next/link";

export function Footer({ locale }: { locale: Locale }) {
  const dict = getDictionary(locale);

  return (
    <footer className="border-t border-black/5 bg-ink text-white">
      <div className="mx-auto grid max-w-6xl gap-10 px-4 py-14 md:grid-cols-4 md:px-6">
        <div className="md:col-span-2">
          <p className="font-serif text-2xl font-bold">{SITE.name}</p>
          <p className="mt-3 max-w-md text-sm text-white/70">{SITE.tagline}</p>
        </div>

        <div>
          <p className="text-xs font-bold uppercase tracking-wider text-gold">{dict.footer.product}</p>
          <ul className="mt-4 space-y-2 text-sm text-white/80">
            <li><Link href="/creators" className="hover:text-white">{dict.footer.creators}</Link></li>
            <li><Link href="/brands" className="hover:text-white">{dict.footer.brands}</Link></li>
            <li><Link href="/faq" className="hover:text-white">{dict.footer.faq}</Link></li>
            <li><Link href="/demo" className="hover:text-white">{dict.footer.demo}</Link></li>
          </ul>
        </div>

        <div>
          <p className="text-xs font-bold uppercase tracking-wider text-gold">{dict.footer.legal}</p>
          <ul className="mt-4 space-y-2 text-sm text-white/80">
            <li><Link href="/privacy" className="hover:text-white">{dict.footer.privacy}</Link></li>
            <li><Link href="/terms" className="hover:text-white">{dict.footer.terms}</Link></li>
            <li><Link href="/community-guidelines" className="hover:text-white">{dict.footer.guidelines}</Link></li>
            <li><Link href="/contact" className="hover:text-white">{dict.footer.contact}</Link></li>
            <li><Link href="/delete-account" className="hover:text-white">{dict.footer.deleteAccount}</Link></li>
          </ul>
        </div>
      </div>

      <div className="border-t border-white/10 px-4 py-6 text-center text-xs text-white/50 md:px-6">
        © {new Date().getFullYear()} {SITE.name}. All rights reserved.
      </div>
    </footer>
  );
}
