import Link from "next/link";
import { BrandMark } from "@/components/brand/BrandMark";
import { LocaleSwitcher } from "@/components/marketing/LocaleSwitcher";
import { MobileMenu } from "@/components/marketing/MobileMenu";
import { NAV_LINKS } from "@/config/site";
import { type Locale, getDictionary } from "@/lib/i18n/dictionaries";

export function Header({ locale }: { locale: Locale }) {
  const dict = getDictionary(locale);

  const navLabel = (label: string) => {
    if (label === "Brands") return dict.nav.brands;
    if (label === "Creators") return dict.nav.creators;
    if (label === "FAQ") return dict.nav.faq;
    return dict.nav.demo;
  };

  return (
    <header className="sticky top-0 z-50 border-b border-border bg-surface/90 backdrop-blur-md">
      <div className="mx-auto flex max-w-6xl items-center justify-between gap-3 px-4 py-3 md:gap-4 md:px-6 md:py-4">
        <Link href="/" className="flex min-w-0 items-center gap-3">
          <BrandMark size={40} />
          <div className="min-w-0">
            <p className="truncate font-serif text-lg font-bold leading-tight text-ink">Marvi Society</p>
            <p className="truncate text-[10px] font-bold uppercase tracking-[0.14em] text-muted">
              Istanbul · {locale === "tr" ? "Özel erişim" : "Private access"}
            </p>
          </div>
        </Link>

        <nav className="hidden items-center gap-6 md:flex">
          {NAV_LINKS.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className="text-sm font-semibold text-graphite transition hover:text-rose"
            >
              {navLabel(link.label)}
            </Link>
          ))}
        </nav>

        <div className="flex items-center gap-2">
          <div className="hidden sm:block">
            <LocaleSwitcher current={locale} />
          </div>
          <Link href="/portal/login" className="marvi-btn-secondary hidden lg:inline-flex">
            {dict.nav.login}
          </Link>
          <Link href="/demo" className="marvi-btn-primary hidden sm:inline-flex">
            {dict.nav.demo}
          </Link>
          <MobileMenu locale={locale} dict={dict} />
        </div>
      </div>
    </header>
  );
}
