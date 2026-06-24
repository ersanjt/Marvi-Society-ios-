"use client";

import { useState } from "react";
import { EmptyState, ListRow, StatusPill, SyncBanner } from "@/components/design/MarviUI";
import { bookingStageTone, formatStatusLabel, proofStatusTone } from "@/lib/operational/status";
import { IconCalendar } from "@/components/design/MarviIcons";
import type { Locale } from "@/lib/i18n/dictionaries";
import type { PortalAdminDict } from "@/lib/i18n/portal-admin";

type ReviewItem = {
  booking_id: string;
  creator_name: string;
  instagram_handle: string;
  venue_name: string;
  offer_title: string;
  stage: string;
  proof_status: string;
};

export function VenueReviewQueue({
  initialItems,
  dict,
  locale,
}: {
  initialItems: ReviewItem[];
  dict: PortalAdminDict;
  locale: Locale;
}) {
  const [items, setItems] = useState(initialItems);
  const [message, setMessage] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const r = dict.portal.reviews;
  const c = dict.common;

  async function submitReview(bookingId: string, punctuality: number, presentation: number, comment: string) {
    setMessage(null);
    setBusyId(bookingId);
    try {
      const response = await fetch("/api/portal/reviews", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ bookingId, punctuality, presentation, comment }),
      });
      const data = await response.json();
      if (!response.ok) {
        setMessage(data.error ?? r.submitFailed);
        return;
      }
      setItems((current) => current.filter((item) => item.booking_id !== bookingId));
      setMessage(r.submitSuccess);
    } finally {
      setBusyId(null);
    }
  }

  if (items.length === 0) {
    return (
      <EmptyState
        icon={<IconCalendar size={24} />}
        title={r.emptyTitle}
        body={r.emptyBody}
      />
    );
  }

  return (
    <div className="space-y-4">
      {message ? <SyncBanner tone="success" message={message} /> : null}

      {items.map((item) => (
        <article key={item.booking_id} className="marvi-card">
          <ListRow
            title={item.creator_name}
            subtitle={`${item.instagram_handle} · ${item.offer_title}`}
            meta={`${item.venue_name} · ${formatStatusLabel(item.stage, locale)}`}
            badge={
              <div className="flex flex-wrap gap-1">
                <StatusPill label={formatStatusLabel(item.stage, locale)} tone={bookingStageTone(item.stage)} />
                <StatusPill
                  label={`${c.proof} ${formatStatusLabel(item.proof_status, locale)}`}
                  tone={proofStatusTone(item.proof_status)}
                />
              </div>
            }
          />

          <form
            className="mt-5 grid gap-3 border-t border-border pt-5 sm:grid-cols-2"
            onSubmit={(event) => {
              event.preventDefault();
              const form = event.currentTarget;
              const data = new FormData(form);
              submitReview(
                item.booking_id,
                Number(data.get("punctuality")),
                Number(data.get("presentation")),
                String(data.get("comment") ?? "")
              );
            }}
          >
            <label className="block text-sm font-semibold text-ink">
              {r.punctuality}
              <input
                name="punctuality"
                type="number"
                min={1}
                max={5}
                defaultValue={5}
                className="mt-1 marvi-input"
              />
            </label>
            <label className="block text-sm font-semibold text-ink">
              {r.presentation}
              <input
                name="presentation"
                type="number"
                min={1}
                max={5}
                defaultValue={5}
                className="mt-1 marvi-input"
              />
            </label>
            <label className="block text-sm font-semibold text-ink sm:col-span-2">
              {r.comment}
              <textarea name="comment" rows={2} className="mt-1 marvi-input" placeholder={r.commentPlaceholder} />
            </label>
            <button type="submit" className="marvi-btn-primary sm:col-span-2" disabled={busyId === item.booking_id}>
              {busyId === item.booking_id ? c.submitting : r.submitReview}
            </button>
          </form>
        </article>
      ))}
    </div>
  );
}
