"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

export function CampaignForm() {
  const router = useRouter();
  const [status, setStatus] = useState<"idle" | "loading" | "done" | "error">("idle");
  const [message, setMessage] = useState("");

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setStatus("loading");
    const form = new FormData(e.currentTarget);
    const deliverables = String(form.get("deliverables") ?? "")
      .split("\n")
      .map((line) => line.trim())
      .filter(Boolean);

    const res = await fetch("/api/portal/offers", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        title: form.get("title"),
        model: form.get("model"),
        slots: Number(form.get("slots")),
        valueLabel: form.get("valueLabel"),
        deliverables,
      }),
    });
    const data = await res.json();
    if (!res.ok) {
      setStatus("error");
      setMessage(data.error ?? "Failed to submit");
      return;
    }
    setStatus("done");
    setMessage(data.message ?? "Campaign submitted for review.");
    router.push("/portal/dashboard");
    router.refresh();
  }

  return (
    <form className="marvi-card mt-8 space-y-4" onSubmit={onSubmit}>
      <label className="block text-sm font-semibold">
        Campaign title
        <input name="title" required className="mt-1 marvi-input" />
      </label>
      <label className="block text-sm font-semibold">
        Collaboration model
        <select name="model" className="mt-1 marvi-input">
          <option value="invitation">Invitation</option>
          <option value="event">Event</option>
          <option value="gift">Gift</option>
          <option value="instant">Instant</option>
        </select>
      </label>
      <label className="block text-sm font-semibold">
        Creator value (e.g. Dinner for 2)
        <input name="valueLabel" className="mt-1 marvi-input" />
      </label>
      <label className="block text-sm font-semibold">
        Creator slots
        <input name="slots" type="number" min={1} defaultValue={5} required className="mt-1 marvi-input" />
      </label>
      <label className="block text-sm font-semibold">
        Deliverables (one per line)
        <textarea
          name="deliverables"
          rows={4}
          required
          className="mt-1 marvi-input"
          placeholder={"3 Instagram stories\n1 Reel"}
        />
      </label>
      <button type="submit" className="marvi-btn-primary w-full" disabled={status === "loading"}>
        {status === "loading" ? "Submitting…" : "Submit for review"}
      </button>
      {message ? <p className={`text-sm ${status === "error" ? "text-tomato" : "text-emerald"}`}>{message}</p> : null}
    </form>
  );
}
