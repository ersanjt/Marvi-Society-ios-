"use client";

import { useState } from "react";
import { PhoneFrame } from "@/components/marketing/AppScreenshot";
import { APP_SCREENSHOTS } from "@/components/marketing/AppScreenshot";
import type { Locale } from "@/lib/i18n/dictionaries";

export function AppShowcase({ locale }: { locale: Locale }) {
  const [active, setActive] = useState(0);
  const screen = APP_SCREENSHOTS[active];
  const isTr = locale === "tr";

  return (
    <div className="grid items-center gap-10 lg:grid-cols-[1fr,minmax(260px,300px)]">
      <div>
        <div className="flex flex-wrap gap-2">
          {APP_SCREENSHOTS.map((item, index) => (
            <button
              key={item.id}
              type="button"
              onClick={() => setActive(index)}
              className={
                index === active
                  ? "marvi-pill bg-brand-gradient text-white shadow-rose"
                  : "marvi-pill border border-border bg-panel text-graphite transition hover:border-rose/30"
              }
            >
              {isTr ? item.label : item.labelEn}
            </button>
          ))}
        </div>
        <h3 className="mt-8 font-serif text-2xl font-bold text-ink md:text-3xl">
          {isTr ? screen.label : screen.labelEn}
        </h3>
        <p className="mt-3 max-w-lg text-muted">
          {isTr ? screen.captionTr : screen.caption}
        </p>
        <p className="mt-6 text-xs font-bold uppercase tracking-[0.14em] text-gold">
          {active + 1} / {APP_SCREENSHOTS.length}
        </p>
      </div>

      <PhoneFrame
        src={screen.src}
        alt={isTr ? screen.label : screen.labelEn}
        priority={active === 0}
      />
    </div>
  );
}
