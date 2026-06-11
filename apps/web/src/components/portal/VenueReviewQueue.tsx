"use client";

import { useState } from "react";

type ReviewItem = {
  booking_id: string;
  creator_name: string;
  instagram_handle: string;
  venue_name: string;
  offer_title: string;
  stage: string;
  proof_status: string;
};

export function VenueReviewQueue({ initialItems }: { initialItems: ReviewItem[] }) {
  const [items, setItems] = useState(initialItems);
  const [message, setMessage] = useState<string | null>(null);

  async function submitReview(bookingId: string, punctuality: number, presentation: number, comment: string) {
    setMessage(null);
    const response = await fetch("/api/portal/reviews", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ bookingId, punctuality, presentation, comment }),
    });
    const data = await response.json();
    if (!response.ok) {
      setMessage(data.error ?? "Could not submit review");
      return;
    }
    setItems((current) => current.filter((item) => item.booking_id !== bookingId));
    setMessage("Review submitted.");
  }

  if (items.length === 0) {
    return <div className="marvi-card p-8 text-center text-muted">No creators waiting for review.</div>;
  }

  return (
    <div className="space-y-4">
      {message ? <p className="rounded-xl bg-emerald/10 p-3 text-sm text-emerald">{message}</p> : null}
      {items.map((item) => (
        <article key={item.booking_id} className="marvi-card p-5">
          <h2 className="font-bold text-ink">{item.creator_name}</h2>
          <p className="text-sm text-muted">
            {item.instagram_handle} · {item.offer_title} · {item.stage} · proof {item.proof_status}
          </p>
          <form
            className="mt-4 grid gap-3 sm:grid-cols-2"
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
            <label className="text-sm">
              Punctuality
              <input name="punctuality" type="number" min={1} max={5} defaultValue={5} className="mt-1 w-full rounded-lg border px-3 py-2" />
            </label>
            <label className="text-sm">
              Presentation
              <input name="presentation" type="number" min={1} max={5} defaultValue={5} className="mt-1 w-full rounded-lg border px-3 py-2" />
            </label>
            <label className="text-sm sm:col-span-2">
              Comment
              <textarea name="comment" rows={2} className="mt-1 w-full rounded-lg border px-3 py-2" />
            </label>
            <button type="submit" className="marvi-btn-primary sm:col-span-2">
              Submit review
            </button>
          </form>
        </article>
      ))}
    </div>
  );
}
