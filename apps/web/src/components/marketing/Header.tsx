import { LocaleSwitcher } from "@/components/marketing/LocaleSwitcher";
import { NAV_LINKS, SITE } from "@/lib/constants";
import { type Locale, getDictionary } from "@/lib/i18n/dictionaries";
import Link from "next/link";

export function Header({ locale }: { locale: Locale }) {
  const dict = getDictionary(locale);

  return (
    <header className="sticky top-0 z-50 border-b border-black/5 bg-surface/90 backdrop-blur-md">
      <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-4 md:px-6">
        <Link href="/" className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-marvi bg-emerald text-sm font-bold text-white">
            M
          </div>
          <div>
            <p className="font-serif text-lg font-bold leading-tight">{SITE.name}</p>
            <p className="text-xs text-muted">Istanbul · Private access</p>
          </div>
        </Link>

        <nav className="hidden items-center gap-6 md:flex">
          {NAV_LINKS.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className="text-sm font-semibold text-graphite transition hover:text-emerald"
            >
              {link.label === "Brands"
                ? dict.nav.brands
                : link.label === "Creators"
                  ? dict.nav.creators
                  : link.label === "FAQ"
                    ? dict.nav.faq
                    : dict.nav.demo}
            </Link>
          ))}
        </nav>

        <div className="flex items-center gap-2">
          <LocaleSwitcher current={locale} />
          <Link href="/portal/login" className="marvi-btn-secondary hidden sm:inline-flex">
            {dict.nav.login}
          </Link>
          <Link href="/demo" className="marvi-btn-primary">
            {dict.nav.demo}
          </Link>
        </div>
      </div>
    </header>
  );
}
