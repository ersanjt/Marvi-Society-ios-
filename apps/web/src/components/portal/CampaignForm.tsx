"use client";

import { CollaborationModelPicker } from "@/components/portal/CreatorSwipeDeck";
import { SyncBanner } from "@/components/design/MarviUI";
import type { PortalAdminDict } from "@/lib/i18n/portal-admin";
import { useRouter } from "next/navigation";
import { useState } from "react";

export function CampaignForm({ dict }: { dict: PortalAdminDict }) {
  const router = useRouter();
  const [status, setStatus] = useState<"idle" | "loading" | "done" | "error">("idle");
  const [message, setMessage] = useState("");
  const [model, setModel] = useState("invitation");
  const c = dict.portal.campaign;

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
        model,
        slots: Number(form.get("slots")),
        valueLabel: form.get("valueLabel"),
        deliverables,
      }),
    });
    const data = await res.json();
    if (!res.ok) {
      setStatus("error");
      setMessage(data.error ?? c.submitFailed);
      return;
    }
    setStatus("done");
    setMessage(data.message ?? c.submitSuccess);
    router.push("/portal/dashboard");
    router.refresh();
  }

  return (
    <form className="marvi-card mt-8 space-y-5" onSubmit={onSubmit}>
      <div>
        <p className="marvi-eyebrow">{c.step1}</p>
        <label className="mt-2 block text-sm font-semibold text-ink">
          {c.campaignTitle}
          <input name="title" required className="mt-1 marvi-input" placeholder={c.titlePlaceholder} />
        </label>
      </div>

      <div>
        <p className="marvi-eyebrow">{c.step2}</p>
        <p className="mt-2 text-sm font-semibold text-ink">{c.collaborationModel}</p>
        <input type="hidden" name="model" value={model} />
        <div className="mt-2">
          <CollaborationModelPicker dict={dict} value={model} onChange={setModel} />
        </div>
      </div>

      <label className="block text-sm font-semibold text-ink">
        {c.creatorValue}
        <input name="valueLabel" className="mt-1 marvi-input" placeholder={c.valuePlaceholder} />
      </label>

      <label className="block text-sm font-semibold text-ink">
        {c.creatorSlots}
        <input name="slots" type="number" min={1} defaultValue={5} required className="mt-1 marvi-input" />
      </label>

      <label className="block text-sm font-semibold text-ink">
        {c.deliverables}
        <textarea
          name="deliverables"
          rows={4}
          required
          className="mt-1 marvi-input"
          placeholder={c.deliverablesPlaceholder}
        />
      </label>

      <p className="text-xs text-muted">{c.reviewNote}</p>

      <button type="submit" className="marvi-btn-primary w-full" disabled={status === "loading"}>
        {status === "loading" ? dict.common.submitting : c.submitForReview}
      </button>

      {message ? (
        <SyncBanner tone={status === "error" ? "error" : "success"} message={message} />
      ) : null}
    </form>
  );
}
