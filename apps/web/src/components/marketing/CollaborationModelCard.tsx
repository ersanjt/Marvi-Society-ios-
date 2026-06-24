import { COLLABORATION_ICON_MAP } from "@/components/design/MarviIcons";
import type { Locale } from "@/lib/i18n/dictionaries";

type Model = {
  id: string;
  title: string;
  titleTr: string;
  description: string;
  descriptionTr: string;
  iconId: keyof typeof COLLABORATION_ICON_MAP;
};

export function CollaborationModelCard({ model, locale }: { model: Model; locale: Locale }) {
  const Icon = COLLABORATION_ICON_MAP[model.iconId];
  const isTr = locale === "tr";

  return (
    <article className="marvi-card group transition hover:border-rose/25">
      <div className="flex items-start gap-4">
        <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-marvi bg-rose/15 text-rose transition group-hover:bg-brand-gradient group-hover:text-white">
          <Icon size={22} />
        </div>
        <div>
          <h3 className="text-lg font-bold text-ink">{isTr ? model.titleTr : model.title}</h3>
          <p className="mt-2 text-sm leading-relaxed text-muted">
            {isTr ? model.descriptionTr : model.description}
          </p>
        </div>
      </div>
    </article>
  );
}
