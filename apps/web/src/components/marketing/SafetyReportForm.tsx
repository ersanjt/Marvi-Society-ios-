"use client";

import { useState } from "react";
import type { ContactFormDict } from "@/lib/i18n/dictionaries";

export function SafetyReportForm({ t }: { t: ContactFormDict }) {
  const [status, setStatus] = useState<"idle" | "loading" | "done" | "error">("idle");
  const [message, setMessage] = useState("");

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setStatus("loading");
    setMessage("");

    const form = new FormData(e.currentTarget);
    const res = await fetch("/api/safety-reports", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email: form.get("email"),
        body: form.get("body"),
        category: "safety",
      }),
    });
    const data = await res.json().catch(() => ({}));

    if (!res.ok) {
      setStatus("error");
      setMessage(typeof data.error === "string" ? data.error : t.safetyFailed);
      return;
    }

    setStatus("done");
    setMessage(t.safetySent);
    e.currentTarget.reset();
  }

  return (
    <form className="mt-4 space-y-3" onSubmit={onSubmit}>
      <label className="block text-sm font-semibold">
        {t.email}
        <input type="email" name="email" className="mt-1 marvi-input" autoComplete="email" />
      </label>
      <label className="block text-sm font-semibold">
        {t.message}
        <textarea
          name="body"
          rows={4}
          required
          minLength={8}
          className="mt-1 marvi-input"
          placeholder={t.safetyPlaceholder}
        />
      </label>
      <button type="submit" className="marvi-btn-secondary" disabled={status === "loading"}>
        {status === "loading" ? t.sending : t.safetyCta}
      </button>
      {message ? (
        <p className={`text-sm ${status === "error" ? "text-tomato" : "text-emerald"}`}>{message}</p>
      ) : null}
    </form>
  );
}
