"use client";

import { useState } from "react";

export function ContactForm({ supportEmail }: { supportEmail: string }) {
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
      setMessage(data.error ?? "Failed to send message.");
      return;
    }

    setStatus("done");
    setMessage(data.message ?? data.warning ?? "Message sent.");
    e.currentTarget.reset();
  }

  return (
    <form className="marvi-card mt-6 space-y-4" onSubmit={onSubmit}>
      <div className="grid gap-4 md:grid-cols-2">
        <label className="block text-sm font-semibold">
          Name
          <input name="name" required className="mt-1 marvi-input" autoComplete="name" />
        </label>
        <label className="block text-sm font-semibold">
          Email
          <input type="email" name="email" required className="mt-1 marvi-input" autoComplete="email" />
        </label>
      </div>
      <label className="block text-sm font-semibold">
        Subject
        <select name="subject" className="mt-1 marvi-input" defaultValue="General support">
          <option>General support</option>
          <option>Account help</option>
          <option>Campaign / booking</option>
          <option>Safety report</option>
          <option>Partnership</option>
        </select>
      </label>
      <label className="block text-sm font-semibold">
        Message
        <textarea name="message" rows={5} required className="mt-1 marvi-input" />
      </label>
      <button type="submit" className="marvi-btn-primary w-full" disabled={status === "loading"}>
        {status === "loading" ? "Sending…" : "Send message"}
      </button>
      {message ? (
        <p className={`text-sm ${status === "error" ? "text-tomato" : "text-emerald"}`}>{message}</p>
      ) : null}
      <p className="text-xs text-muted">
        Or email us directly at{" "}
        <a href={`mailto:${supportEmail}`} className="marvi-link">
          {supportEmail}
        </a>
      </p>
    </form>
  );
}
