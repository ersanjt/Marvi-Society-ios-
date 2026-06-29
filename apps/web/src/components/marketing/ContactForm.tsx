"use client";

import { useState } from "react";
import type { ContactFormDict } from "@/lib/i18n/dictionaries";

export function ContactForm({ supportEmail, t }: { supportEmail: string; t: ContactFormDict }) {
  const [status, setStatus] = useState<"idle" | "loading" | "done" | "error">("idle");
  const [message, setMessage] = useState("");

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setStatus("loading");
    setMessage("");

    const form = new FormData(e.currentTarget);
    const res = await fetch("/api/contact", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        name: form.get("name"),
        email: form.get("email"),
        subject: form.get("subject"),
        message: form.get("message"),
      }),
    });
    const data = await res.json();

    if (!res.ok) {
      setStatus("error");
      setMessage(data.error ?? t.failed);
      return;
    }

    setStatus("done");
    setMessage(data.message ?? data.warning ?? t.sent);
    e.currentTarget.reset();
  }

  return (
    <form className="marvi-card mt-6 space-y-4" onSubmit={onSubmit}>
      <div className="grid gap-4 md:grid-cols-2">
        <label className="block text-sm font-semibold">
          {t.name}
          <input name="name" required className="mt-1 marvi-input" autoComplete="name" />
        </label>
        <label className="block text-sm font-semibold">
          {t.email}
          <input type="email" name="email" required className="mt-1 marvi-input" autoComplete="email" />
        </label>
      </div>
      <label className="block text-sm font-semibold">
        {t.subject}
        <select name="subject" className="mt-1 marvi-input" defaultValue="general">
          <option value="general">{t.subjectGeneral}</option>
          <option value="account">{t.subjectAccount}</option>
          <option value="campaign">{t.subjectCampaign}</option>
          <option value="safety">{t.subjectSafety}</option>
          <option value="partnership">{t.subjectPartnership}</option>
        </select>
      </label>
      <label className="block text-sm font-semibold">
        {t.message}
        <textarea name="message" rows={5} required className="mt-1 marvi-input" />
      </label>
      <button type="submit" className="marvi-btn-primary w-full" disabled={status === "loading"}>
        {status === "loading" ? t.sending : t.submit}
      </button>
      {message ? (
        <p className={`text-sm ${status === "error" ? "text-tomato" : "text-emerald"}`}>{message}</p>
      ) : null}
      <p className="text-xs text-muted">
        {t.orEmail}{" "}
        <a href={`mailto:${supportEmail}`} className="marvi-link">
          {supportEmail}
        </a>
      </p>
    </form>
  );
}
