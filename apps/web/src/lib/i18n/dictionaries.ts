export type Locale = "en" | "tr";

export const dictionaries = {
  en: {
    nav: { brands: "Brands", creators: "Creators", faq: "FAQ", demo: "Get demo", login: "Brand login" },
    hero: {
      eyebrow: "Istanbul private collaboration marketplace",
      title: "Where approved creators and curated venues collaborate",
      ctaCreators: "For creators",
      ctaBrands: "For brands",
    },
    footer: {
      product: "Product",
      legal: "Legal",
      creators: "Creators",
      brands: "Brands",
      faq: "FAQ",
      demo: "Demo",
      privacy: "Privacy",
      terms: "Terms",
      guidelines: "Community",
      contact: "Contact",
      deleteAccount: "Delete account",
    },
  },
  tr: {
    nav: { brands: "Markalar", creators: "İçerik Üreticileri", faq: "SSS", demo: "Demo Al", login: "Marka Girişi" },
    hero: {
      eyebrow: "İstanbul özel iş birliği platformu",
      title: "Onaylı içerik üreticileri ve seçkin mekanlar bir arada",
      ctaCreators: "İçerik üreticileri",
      ctaBrands: "Markalar",
    },
    footer: {
      product: "Ürün",
      legal: "Yasal",
      creators: "İçerik Üreticileri",
      brands: "Markalar",
      faq: "SSS",
      demo: "Demo",
      privacy: "Gizlilik",
      terms: "Şartlar",
      guidelines: "Topluluk",
      contact: "İletişim",
      deleteAccount: "Hesabı sil",
    },
  },
} as const;

export function getDictionary(locale: Locale) {
  return dictionaries[locale] ?? dictionaries.en;
}
