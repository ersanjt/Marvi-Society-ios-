"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { BrandMark } from "@/components/brand/BrandMark";
import { LocaleSwitcher } from "@/components/marketing/LocaleSwitcher";
import { NAV_LINKS } from "@/config/site";
import type { Locale } from "@/lib/i18n/dictionaries";

type MobileMenuProps = {
  locale: Locale;
  dict: {
    nav: {
      brands: string;
      creators: string;
      faq: string;
      demo: string;
      login: string;
    };
  };
};

export function MobileMenu({ locale, dict }: MobileMenuProps) {
  const [open, setOpen] = useState(false);

  useEffect(() => {
    document.body.style.overflow = open ? "hidden" : "";
    return () => {
      document.body.style.overflow = "";
    };
  }, [open]);

  const navLabel = (label: string) => {
    if (label === "Brands") return dict.nav.brands;
    if (label === "Creators") return dict.nav.creators;
    if (label === "FAQ") return dict.nav.faq;
    return dict.nav.demo;
  };

  return (
    <div className="md:hidden">
      <button
        type="button"
        aria-expanded={open}
        aria-label={open ? "Close menu" : "Open menu"}
        onClick={() => setOpen((v) => !v)}
        className="flex h-10 w-10 items-center justify-center rounded-marvi border border-border bg-panel-elevated text-ink"
      >
        <span className="sr-only">Menu</span>
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          {open ? (
            <path d="M6 6l12 12M18 6 6 18" />
          ) : (
            <>
              <path d="M4 7h16M4 12h16M4 17h16" />
            </>
          )}
        </svg>
      </button>

      {open ? (
        <div className="fixed inset-0 z-[60] bg-surface/95 backdrop-blur-md">
          <div className="flex items-center justify-between border-b border-border px-4 py-4">
            <div className="flex items-center gap-2">
              <BrandMark size={36} />
              <span className="font-serif text-lg font-bold text-ink">Marvi Society</span>
            </div>
            <button
              type="button"
              onClick={() => setOpen(false)}
              className="flex h-10 w-10 items-center justify-center rounded-marvi border border-border text-ink"
              aria-label="Close menu"
            >
              ✕
            </button>
          </div>

          <nav className="flex flex-col gap-1 px-4 py-6">
            {NAV_LINKS.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                onClick={() => setOpen(false)}
                className="rounded-marvi px-4 py-3 text-base font-semibold text-ink transition hover:bg-panel"
              >
                {navLabel(link.label)}
              </Link>
            ))}
            <Link
              href="/portal/login"
              onClick={() => setOpen(false)}
              className="mt-4 marvi-btn-secondary w-full"
            >
              {dict.nav.login}
            </Link>
            <Link
              href="/demo"
              onClick={() => setOpen(false)}
              className="marvi-btn-primary w-full"
            >
              {dict.nav.demo}
            </Link>
            <div className="mt-6 flex justify-center">
              <LocaleSwitcher current={locale} />
            </div>
          </nav>
        </div>
      ) : null}
    </div>
  );
}
