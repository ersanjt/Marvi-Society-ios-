import type { LegalDocument as LegalDocumentType } from "@/lib/legal/types";

export function LegalDocument({ doc }: { doc: LegalDocumentType }) {
  return (
    <div className="marvi-legal mt-10 max-w-none space-y-8">
      <p className="text-muted">{doc.intro}</p>

      {doc.sections.map((section) => (
        <section key={section.id} id={section.id}>
          <h2>{section.title}</h2>
          {section.paragraphs?.map((paragraph) => (
            <p key={paragraph.slice(0, 24)}>{paragraph}</p>
          ))}
          {section.bullets ? (
            <ul>
              {section.bullets.map((item) => (
                <li key={item.slice(0, 32)}>{item}</li>
              ))}
            </ul>
          ) : null}
        </section>
      ))}

      <p className="border-t border-border pt-6 text-sm text-muted">{doc.contactNote}</p>
    </div>
  );
}
