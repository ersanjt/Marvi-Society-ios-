export function SectionHeading({
  eyebrow,
  title,
  subtitle,
}: {
  eyebrow?: string;
  title: string;
  subtitle?: string;
}) {
  return (
    <div className="max-w-2xl">
      {eyebrow ? <p className="marvi-eyebrow">{eyebrow}</p> : null}
      <h2 className="mt-2 font-serif text-3xl font-bold text-ink md:text-4xl">{title}</h2>
      {subtitle ? <p className="mt-3 text-base text-muted">{subtitle}</p> : null}
    </div>
  );
}
