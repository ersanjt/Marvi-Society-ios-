export type LegalLocale = "en" | "tr";

export type LegalSection = {
  id: string;
  title: string;
  paragraphs?: string[];
  bullets?: string[];
};

export type LegalDocument = {
  title: string;
  subtitle: string;
  intro: string;
  sections: LegalSection[];
  contactNote: string;
};
