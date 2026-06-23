"use client";

import { useState } from "react";

export function DemoForm() {
  const [status, setStatus] = useState<"idle" | "loading" | "done" | "error">("idle");
  const [message, setMessage] = useState("");

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setStatus("loading");
    const form = new FormData(e.currentTarget);
    const res = await fetch("/api/demo", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        firstName: form.get("firstName"),
        lastName: form.get("lastName"),
        company: form.get("company"),
        email: form.get("email"),
        website: form.get("website"),
        message: form.get("message"),
      }),
    });
    const data = await res.json();
    if (!res.ok) {
      setStatus("error");
      setMessage(data.error ?? "Failed");
      return;
    }
    setStatus("done");
    setMessage(data.message ?? "Demo request submitted. We'll contact you soon.");
    e.currentTarget.reset();
  }

  return (
    <form className="marvi-card mt-6 space-y-4" onSubmit={onSubmit}>
      <div className="grid gap-4 md:grid-cols-2">
        <label className="block text-sm font-semibold">
          First name
          <input name="firstName" required className="mt-1 marvi-input" />
        </label>
        <label className="block text-sm font-semibold">
          Last name
          <input name="lastName" required className="mt-1 marvi-input" />
        </label>
      </div>
      <label className="block text-sm font-semibold">
        Company / venue
        <input name="company" required className="mt-1 marvi-input" />
      </label>
      <label className="block text-sm font-semibold">
        Email
        <input type="email" name="email" required className="mt-1 marvi-input" />
      </label>
      <label className="block text-sm font-semibold">
        Website
        <input type="url" name="website" className="mt-1 marvi-input" />
      </label>
      <label className="block text-sm font-semibold">
        Message
        <textarea name="message" rows={4} className="mt-1 marvi-input" />
      </label>
      <button type="submit" className="marvi-btn-primary w-full" disabled={status === "loading"}>
        {status === "loading" ? "Sending…" : "Request demo"}
      </button>
      {message ? (
        <p className={`text-sm ${status === "error" ? "text-tomato" : "text-emerald"}`}>{message}</p>
      ) : null}
    </form>
  );
}
