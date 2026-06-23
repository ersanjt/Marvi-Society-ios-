"use client";

import { useState } from "react";

type Step = "email" | "code" | "done";

export function DeleteAccountForm({ supportEmail }: { supportEmail: string }) {
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
      setMessage(data.error ?? "Failed to send code");
      return;
    }

    setMessage(data.message ?? "Verification code sent.");
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
      setMessage(data.error ?? "Deletion failed");
      return;
    }

    setMessage(data.message ?? "Account deleted.");
    setStep("done");
  }

  if (step === "done") {
    return (
      <div className="marvi-card mt-10 space-y-4 text-center">
        <p className="text-sm font-semibold text-emerald">{message}</p>
        <p className="text-xs text-muted">You may close this page. The iOS app will require a new sign-in.</p>
      </div>
    );
  }

  if (step === "code") {
    return (
      <form className="marvi-card mt-10 space-y-4" onSubmit={confirmDeletion}>
        <p className="text-sm text-muted">{message}</p>
        <label className="block text-sm font-semibold">
          6-digit verification code
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
        <p className="text-xs text-muted">
          Enter the code from your email. Deletion is permanent and removes bookings, profile data, and proof history.
        </p>
        <button type="submit" className="marvi-btn-primary w-full" disabled={status === "loading"}>
          {status === "loading" ? "Deleting…" : "Permanently delete account"}
        </button>
        {status === "error" && message ? <p className="text-sm text-tomato">{message}</p> : null}
        <button type="button" className="w-full text-xs text-muted underline" onClick={() => setStep("email")}>
          Use a different email
        </button>
      </form>
    );
  }

  return (
    <form className="marvi-card mt-10 space-y-4" onSubmit={requestCode}>
      <label className="block text-sm font-semibold">
        Registered email
        <input
          type="email"
          name="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="mt-1 marvi-input"
          placeholder="you@example.com"
        />
      </label>
      <p className="text-xs text-muted">
        We will email a one-time verification code. Apple requires that you can delete your account and associated data.
      </p>
      <button type="submit" className="marvi-btn-primary w-full" disabled={status === "loading"}>
        {status === "loading" ? "Sending…" : "Send verification code"}
      </button>
      {message && status === "error" ? <p className="text-sm text-tomato">{message}</p> : null}
      <p className="text-center text-xs text-muted">
        Need help?{" "}
        <a href={`mailto:${supportEmail}`} className="marvi-link">
          {supportEmail}
        </a>
      </p>
    </form>
  );
}
