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
  const [photoPreview, setPhotoPreview] = useState<string | null>(null);
  const [photoFile, setPhotoFile] = useState<File | null>(null);
  const c = dict.portal.campaign;

  function onPhotoChange(file: File | null) {
    if (photoPreview) URL.revokeObjectURL(photoPreview);
    setPhotoFile(file);
    setPhotoPreview(file ? URL.createObjectURL(file) : null);
  }

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setStatus("loading");
    setMessage("");
    const form = new FormData(e.currentTarget);
    const deliverables = String(form.get("deliverables") ?? "")
      .split("\n")
      .map((line) => line.trim())
      .filter(Boolean);
    const requirements = String(form.get("requirements") ?? "")
      .split("\n")
      .map((line) => line.trim())
      .filter(Boolean);

    const payload = new FormData();
    payload.set("title", String(form.get("title") ?? ""));
    payload.set("model", model);
    payload.set("slots", String(form.get("slots") ?? "5"));
    payload.set("valueLabel", String(form.get("valueLabel") ?? ""));
    payload.set("dateLabel", String(form.get("dateLabel") ?? ""));
    payload.set("timeLabel", String(form.get("timeLabel") ?? ""));
    payload.set("description", String(form.get("description") ?? ""));
    payload.set("hostNote", String(form.get("hostNote") ?? ""));
    payload.set("deliverables", JSON.stringify(deliverables));
    payload.set("requirements", JSON.stringify(requirements));
    if (photoFile) payload.set("image", photoFile);

    const res = await fetch("/api/portal/offers", {
      method: "POST",
      body: payload,
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
          {c.campaignPhoto}
          <input
            type="file"
            accept="image/*"
            className="mt-1 block w-full text-sm text-muted file:mr-3 file:rounded-full file:border-0 file:bg-rose/15 file:px-4 file:py-2 file:text-sm file:font-semibold file:text-rose"
            onChange={(e) => onPhotoChange(e.target.files?.[0] ?? null)}
          />
        </label>
        {photoPreview ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={photoPreview}
            alt=""
            className="mt-3 h-40 w-full rounded-xl object-cover"
          />
        ) : null}
        <label className="mt-4 block text-sm font-semibold text-ink">
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
        {c.eventDate}
        <input name="dateLabel" type="date" required className="mt-1 marvi-input" />
      </label>

      <label className="block text-sm font-semibold text-ink">
        {c.eventTime}
        <input name="timeLabel" className="mt-1 marvi-input" placeholder={c.timePlaceholder} />
      </label>

      <label className="block text-sm font-semibold text-ink">
        {c.creatorValue}
        <input name="valueLabel" className="mt-1 marvi-input" placeholder={c.valuePlaceholder} />
      </label>

      <label className="block text-sm font-semibold text-ink">
        {c.description}
        <textarea
          name="description"
          rows={3}
          className="mt-1 marvi-input"
          placeholder={c.descriptionPlaceholder}
        />
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

      <label className="block text-sm font-semibold text-ink">
        {c.requirements}
        <textarea
          name="requirements"
          rows={3}
          className="mt-1 marvi-input"
          placeholder={c.requirementsPlaceholder}
        />
      </label>

      <label className="block text-sm font-semibold text-ink">
        {c.hostNote}
        <textarea
          name="hostNote"
          rows={2}
          className="mt-1 marvi-input"
          placeholder={c.hostNotePlaceholder}
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
