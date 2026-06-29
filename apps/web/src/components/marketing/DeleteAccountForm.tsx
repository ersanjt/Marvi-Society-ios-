"use client";

import { useState } from "react";
import type { DeleteAccountFormDict } from "@/lib/i18n/dictionaries";

type Step = "email" | "code" | "done";

export function DeleteAccountForm({ supportEmail, t }: { supportEmail: string; t: DeleteAccountFormDict }) {
  const [step, setStep] = useState<Step>("email");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [status, setStatus] = useState<"idle" | "loading" | "error">("idle");
  const [message, setMessage] = useState("");

  async function requestCode(e: React.FormEvent) {
    e.preventDefault();
    setStatus("loading");
    setMessage("");

    const res = await fetch("/api/delete-account", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email }),
    });
    const data = await res.json();

    setStatus("idle");
    if (!res.ok) {
      setStatus("error");
      setMessage(data.error ?? t.failedSend);
      return;
    }

    setMessage(data.message ?? t.codeSentDefault);
    setStep("code");
  }

  async function confirmDeletion(e: React.FormEvent) {
    e.preventDefault();
    setStatus("loading");
    setMessage("");

    const res = await fetch("/api/delete-account/confirm", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, code }),
    });
    const data = await res.json();

    setStatus("idle");
    if (!res.ok) {
      setStatus("error");
      setMessage(data.error ?? t.failedDelete);
      return;
    }

    setMessage(data.message ?? t.deletedDefault);
    setStep("done");
  }

  if (step === "done") {
    return (
      <div className="marvi-card mt-10 space-y-4 text-center">
        <p className="text-sm font-semibold text-emerald">{message}</p>
        <p className="text-xs text-muted">{t.doneNote}</p>
      </div>
    );
  }

  if (step === "code") {
    return (
      <form className="marvi-card mt-10 space-y-4" onSubmit={confirmDeletion}>
        <p className="text-sm text-muted">{message}</p>
        <label className="block text-sm font-semibold">
          {t.codeLabel}
          <input
            type="text"
            inputMode="numeric"
            pattern="[0-9]*"
            maxLength={8}
            required
            value={code}
            onChange={(e) => setCode(e.target.value)}
            className="mt-1 marvi-input tracking-widest"
            placeholder="000000"
          />
        </label>
        <p className="text-xs text-muted">{t.codeHint}</p>
        <button type="submit" className="marvi-btn-primary w-full" disabled={status === "loading"}>
          {status === "loading" ? t.deleting : t.deleteBtn}
        </button>
        {status === "error" && message ? <p className="text-sm text-tomato">{message}</p> : null}
        <button type="button" className="w-full text-xs text-muted underline" onClick={() => setStep("email")}>
          {t.useDifferentEmail}
        </button>
      </form>
    );
  }

  return (
    <form className="marvi-card mt-10 space-y-4" onSubmit={requestCode}>
      <label className="block text-sm font-semibold">
        {t.emailLabel}
        <input
          type="email"
          name="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="mt-1 marvi-input"
          placeholder="you@example.com"
          autoComplete="email"
        />
      </label>
      <p className="text-xs text-muted">{t.emailHint}</p>
      <button type="submit" className="marvi-btn-primary w-full" disabled={status === "loading"}>
        {status === "loading" ? t.sending : t.sendCode}
      </button>
      {message && status === "error" ? <p className="text-sm text-tomato">{message}</p> : null}
      <p className="text-center text-xs text-muted">
        {t.needHelp}{" "}
        <a href={`mailto:${supportEmail}`} className="marvi-link">
          {supportEmail}
        </a>
      </p>
    </form>
  );
}
