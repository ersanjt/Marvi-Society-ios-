"use client";

import { useState } from "react";

export function DeleteAccountForm({ supportEmail }: { supportEmail: string }) {
  const [status, setStatus] = useState<"idle" | "loading" | "done" | "error">("idle");
  const [message, setMessage] = useState("");

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setStatus("loading");
    const email = String(new FormData(e.currentTarget).get("email"));
    const res = await fetch("/api/delete-account", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email }),
    });
    const data = await res.json();
    if (!res.ok) {
      setStatus("error");
      setMessage(data.error ?? "Failed");
      return;
    }
    setStatus("done");
    setMessage(data.message ?? "Verification code sent.");
  }

  return (
    <form className="marvi-card mt-10 space-y-4" onSubmit={onSubmit}>
      <label className="block text-sm font-semibold">
        Registered email
        <input
          type="email"
          name="email"
          required
          className="mt-1 w-full rounded-marvi border border-black/10 px-3 py-2"
          placeholder="you@example.com"
        />
      </label>
      <p className="text-xs text-muted">
        OTP verification will be sent to your email. This action is irreversible.
      </p>
      <button type="submit" className="marvi-btn-primary w-full" disabled={status === "loading"}>
        {status === "loading" ? "Sending…" : "Send verification code"}
      </button>
      {message ? (
        <p className={`text-sm ${status === "error" ? "text-tomato" : "text-emerald"}`}>{message}</p>
      ) : null}
      <p className="text-center text-xs text-muted">
        Need help?{" "}
        <a href={`mailto:${supportEmail}`} className="font-bold text-emerald">
          {supportEmail}
        </a>
      </p>
    </form>
  );
}
