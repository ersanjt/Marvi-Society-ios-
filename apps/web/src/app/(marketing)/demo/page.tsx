import { DemoForm } from "@/components/marketing/DemoForm";
import { SectionHeading } from "@/components/marketing/SectionHeading";
import { MarviScreen } from "@/components/design/MarviUI";
import { getI18n } from "@/lib/i18n/locale";
import Link from "next/link";

export const metadata = { title: "Get demo" };

export default async function DemoPage() {
  const { dict } = await getI18n();
  const t = dict.forms.demo;

  return (
    <MarviScreen>
      <div className="mx-auto max-w-2xl px-4 py-16 md:px-6 md:py-24">
        <SectionHeading eyebrow={t.eyebrow} title={t.title} subtitle={t.subtitle} />

        <div className="marvi-card mt-10 border-gold/30 bg-gold/5">
          <p className="text-sm font-semibold leading-relaxed text-graphite">
            {t.creatorNoticePre}{" "}
            <Link href="/creators" className="marvi-link">
              {t.creatorNoticeLink}
            </Link>{" "}
            {t.creatorNoticePost}
          </p>
        </div>

        <DemoForm t={t} />
      </div>
    </MarviScreen>
  );
}
