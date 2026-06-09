"use client";

import { useRouter } from "next/navigation";

export function LocaleSwitcher({ current }: { current: "en" | "tr" }) {
  const router = useRouter();

  function setLocale(locale: "en" | "tr") {
    document.cookie = `locale=${locale};path=/;max-age=31536000`;
    router.refresh();
  }

  return (
    <div className="flex gap-1 rounded-marvi border border-black/10 p-1 text-xs font-bold">
      <button
        type="button"
        onClick={() => setLocale("en")}
        className={`rounded px-2 py-1 ${current === "en" ? "bg-emerald text-white" : "text-muted"}`}
      >
        EN
      </button>
      <button
        type="button"
        onClick={() => setLocale("tr")}
        className={`rounded px-2 py-1 ${current === "tr" ? "bg-emerald text-white" : "text-muted"}`}
      >
        TR
      </button>
    </div>
  );
}
