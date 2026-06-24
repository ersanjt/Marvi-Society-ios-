import { SectionHeading } from "@/components/marketing/SectionHeading";
import { FAQ_ITEMS } from "@/lib/constants";
import { getI18n } from "@/lib/i18n/locale";

export const metadata = { title: "FAQ" };

export default async function FAQPage() {
  const { dict } = await getI18n();

  return (
    <div className="mx-auto max-w-3xl px-4 py-16 md:px-6 md:py-24">
      <SectionHeading title={dict.faq.title} subtitle={dict.faq.subtitle} />

      <div className="mt-12 space-y-10">
        {FAQ_ITEMS.map((section) => (
          <section key={section.category}>
            <h2 className="marvi-eyebrow">{section.category}</h2>
            <div className="mt-4 space-y-3">
              {section.questions.map((item) => (
                <details key={item.q} className="marvi-card group open:border-rose/20">
                  <summary className="cursor-pointer list-none font-bold text-ink marker:content-none">
                    <span className="flex items-center justify-between gap-4">
                      {item.q}
                      <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full border border-border text-muted transition group-open:rotate-45 group-open:border-rose/30 group-open:text-rose">
                        +
                      </span>
                    </span>
                  </summary>
                  <p className="mt-3 text-sm leading-relaxed text-muted">{item.a}</p>
                </details>
              ))}
            </div>
          </section>
        ))}
      </div>
    </div>
  );
}
