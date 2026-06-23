"use client";

import { useRouter } from "next/navigation";

export function LocaleSwitcher({ current }: { current: "en" | "tr" }) {
  const router = useRouter();

  function setLocale(locale: "en" | "tr") {
    document.cookie = `locale=${locale};path=/;max-age=31536000`;
    router.refresh();
  }

  const active = "bg-brand-gradient text-white shadow-rose";
  const idle = "text-muted hover:text-ink";

  return (
    <div className="flex gap-1 rounded-marvi border border-border bg-panel-elevated p-1 text-xs font-bold">
      <button
        type="button"
        onClick={() => setLocale("en")}
        className={`rounded px-2 py-1 ${current === "en" ? active : idle}`}
      >
        EN
      </button>
      <button
        type="button"
        onClick={() => setLocale("tr")}
        className={`rounded px-2 py-1 ${current === "tr" ? active : idle}`}
      >
        TR
      </button>
    </div>
  );
}
