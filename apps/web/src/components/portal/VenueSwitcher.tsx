"use client";

import { useEffect, useState } from "react";

type VenueRow = {
  id: string;
  venue_name: string;
  area: string;
  category: string;
  status: string;
  is_active: boolean;
};

export function VenueSwitcher() {
  const [venues, setVenues] = useState<VenueRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [name, setName] = useState("");
  const [area, setArea] = useState("");
  const [category, setCategory] = useState("dining");
  const [message, setMessage] = useState<string | null>(null);

  async function loadVenues() {
    setLoading(true);
    const res = await fetch("/api/portal/venues");
    const data = await res.json();
    setVenues(data.venues ?? []);
    setLoading(false);
  }

  useEffect(() => {
    loadVenues();
  }, []);

  async function switchVenue(id: string) {
    setMessage(null);
    const res = await fetch("/api/portal/venues", {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ venueId: id }),
    });
    if (!res.ok) {
      const data = await res.json();
      setMessage(data.error ?? "Could not switch venue");
      return;
    }
    await loadVenues();
  }

  async function addVenue(event: React.FormEvent) {
    event.preventDefault();
    setMessage(null);
    const res = await fetch("/api/portal/venues", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ venueName: name, area, category }),
    });
    const data = await res.json();
    if (!res.ok) {
      setMessage(data.error ?? "Could not add venue");
      return;
    }
    setName("");
    setArea("");
    setShowForm(false);
    await loadVenues();
  }

  if (loading) return null;

  return (
    <div className="border-b border-border bg-panel/80 px-4 py-3 md:px-6">
      <div className="mx-auto flex max-w-6xl flex-col gap-3">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <p className="text-xs font-bold uppercase tracking-wide text-muted">Your locations</p>
            <p className="text-sm text-graphite">One account — manage every restaurant, hotel, or shop.</p>
          </div>
          <button
            type="button"
            onClick={() => setShowForm((v) => !v)}
            className="rounded-full bg-gradient-to-r from-rose to-aubergine px-4 py-2 text-sm font-bold text-white"
          >
            Add location
          </button>
        </div>

        {venues.length > 0 && (
          <div className="flex flex-wrap gap-2">
            {venues.map((venue) => (
              <button
                key={venue.id}
                type="button"
                onClick={() => switchVenue(venue.id)}
                className={`rounded-full px-4 py-2 text-sm font-semibold transition ${
                  venue.is_active
                    ? "bg-gradient-to-r from-rose to-aubergine text-white"
                    : "bg-surface text-graphite hover:text-rose"
                }`}
              >
                {venue.venue_name} · {venue.area}
                {venue.status !== "approved" ? " (pending)" : ""}
              </button>
            ))}
          </div>
        )}

        {showForm && (
          <form onSubmit={addVenue} className="grid gap-2 rounded-2xl border border-border bg-surface p-4 md:grid-cols-4">
            <input
              className="rounded-xl border border-border bg-panel px-3 py-2 text-sm"
              placeholder="Venue name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
            />
            <input
              className="rounded-xl border border-border bg-panel px-3 py-2 text-sm"
              placeholder="Area"
              value={area}
              onChange={(e) => setArea(e.target.value)}
              required
            />
            <select
              className="rounded-xl border border-border bg-panel px-3 py-2 text-sm"
              value={category}
              onChange={(e) => setCategory(e.target.value)}
            >
              <option value="dining">Restaurant / Dining</option>
              <option value="wellness">Hotel / Wellness</option>
              <option value="retail">Shop / Retail</option>
              <option value="nightlife">Nightlife</option>
              <option value="beauty">Beauty</option>
              <option value="fitness">Fitness</option>
            </select>
            <button type="submit" className="rounded-xl bg-ink px-4 py-2 text-sm font-bold text-white">
              Submit for review
            </button>
          </form>
        )}

        {message && <p className="text-sm text-rose">{message}</p>}
      </div>
    </div>
  );
}
