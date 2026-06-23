import { SectionHeading } from "@/components/marketing/SectionHeading";
import { FAQ_ITEMS } from "@/lib/constants";

export const metadata = { title: "FAQ" };

export default function FAQPage() {
  return (
    <div className="mx-auto max-w-3xl px-4 py-16 md:px-6 md:py-24">
      <SectionHeading title="Frequently asked questions" subtitle="Membership, collaborations, and venue partnerships." />

      <div className="mt-12 space-y-10">
        {FAQ_ITEMS.map((section) => (
          <section key={section.category}>
            <h2 className="marvi-eyebrow">{section.category}</h2>
            <div className="mt-4 space-y-3">
              {section.questions.map((item) => (
                <details key={item.q} className="marvi-card group">
                  <summary className="cursor-pointer list-none font-bold text-ink marker:content-none">
                    <span className="flex items-center justify-between gap-4">
                      {item.q}
                      <span className="text-muted transition group-open:rotate-45">+</span>
                    </span>
                  </summary>
                  <p className="mt-3 text-sm text-muted">{item.a}</p>
                </details>
              ))}
            </div>
          </section>
        ))}
      </div>
    </div>
  );
}
