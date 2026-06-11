import type { LegalDocument as LegalDocumentType } from "@/lib/legal/types";

export function LegalDocument({ doc }: { doc: LegalDocumentType }) {
  return (
    <div className="prose prose-sm mt-10 max-w-none space-y-8 text-muted">
      <p>{doc.intro}</p>

      {doc.sections.map((section) => (
        <section key={section.id} id={section.id}>
          <h2 className="font-serif text-xl font-bold text-ink">{section.title}</h2>
          {section.paragraphs?.map((paragraph) => (
            <p key={paragraph.slice(0, 24)} className="mt-3">
              {paragraph}
            </p>
          ))}
          {section.bullets ? (
            <ul className="mt-3 list-disc space-y-2 pl-5">
              {section.bullets.map((item) => (
                <li key={item.slice(0, 32)}>{item}</li>
              ))}
            </ul>
          ) : null}
        </section>
      ))}

      <p className="border-t border-black/10 pt-6 text-sm">{doc.contactNote}</p>
    </div>
  );
}
