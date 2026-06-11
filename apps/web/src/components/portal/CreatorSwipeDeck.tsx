"use client";

import { useState } from "react";

type Candidate = {
  creator_id: string;
  full_name: string;
  instagram_handle: string;
  city: string;
  score: number;
  audience_count: number;
};

export function CreatorSwipeDeck({ initialCandidates, offerId }: { initialCandidates: Candidate[]; offerId?: string }) {
  const [candidates, setCandidates] = useState(initialCandidates);
  const [message, setMessage] = useState<string | null>(null);

  async function act(action: "shortlist" | "pass", creatorId: string) {
    setMessage(null);
    const response = await fetch("/api/portal/creators", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action, creatorId, offerId }),
    });
    const data = await response.json();
    if (!response.ok) {
      setMessage(data.error ?? "Action failed");
      return;
    }
    setCandidates((current) => current.filter((item) => item.creator_id !== creatorId));
  }

  const current = candidates[0];
  if (!current) {
    return <div className="marvi-card p-8 text-center text-muted">No more creators in this queue.</div>;
  }

  return (
    <div className="space-y-4">
      {message ? <p className="rounded-xl bg-tomato/10 p-3 text-sm text-tomato">{message}</p> : null}
      <article className="marvi-card p-6">
        <p className="text-xs font-bold uppercase text-gold">Creator match</p>
        <h2 className="font-serif text-2xl font-bold text-ink">{current.full_name}</h2>
        <p className="text-sm text-muted">
          {current.instagram_handle} · {current.city} · score {current.score} · {current.audience_count} audience
        </p>
        <div className="mt-6 flex gap-3">
          <button type="button" className="marvi-btn-secondary flex-1" onClick={() => act("pass", current.creator_id)}>
            Pass
          </button>
          <button type="button" className="marvi-btn-primary flex-1" onClick={() => act("shortlist", current.creator_id)}>
            Shortlist
          </button>
        </div>
      </article>
      <p className="text-xs text-muted">{candidates.length - 1} more in queue</p>
    </div>
  );
}
