"use client";

import { useEffect, useState } from "react";
import { FilterPill, SkeletonBlock, SyncBanner } from "@/components/design/MarviUI";
import type { PortalAdminDict } from "@/lib/i18n/portal-admin";

type VenueRow = {
  id: string;
  venue_name: string;
  area: string;
  category: string;
  status: string;
  is_active: boolean;
};

export function VenueSwitcher({ dict }: { dict: PortalAdminDict }) {
  const [venues, setVenues] = useState<VenueRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [name, setName] = useState("");
  const [area, setArea] = useState("");
  const [category, setCategory] = useState("dining");
  const [message, setMessage] = useState<string | null>(null);
  const v = dict.portal.venues;

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
      setMessage(data.error ?? v.switchFailed);
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
      setMessage(data.error ?? v.addFailed);
      return;
    }
    setName("");
    setArea("");
    setShowForm(false);
    await loadVenues();
  }

  if (loading) {
    return (
      <div className="border-b border-border bg-panel/80 px-4 py-3 md:px-6">
        <div className="mx-auto flex max-w-6xl gap-2">
          <SkeletonBlock className="h-9 w-32" />
          <SkeletonBlock className="h-9 w-40" />
          <SkeletonBlock className="h-9 w-36" />
        </div>
      </div>
    );
  }

  return (
    <div className="border-b border-border bg-panel/80 px-4 py-3 md:px-6">
      <div className="mx-auto flex max-w-6xl flex-col gap-3">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.14em] text-muted">{v.yourLocations}</p>
            <p className="text-sm text-graphite">{v.multiVenueHint}</p>
          </div>
          <button type="button" onClick={() => setShowForm((value) => !value)} className="marvi-btn-primary text-xs">
            {v.addLocation}
          </button>
        </div>

        {venues.length > 0 && (
          <div className="flex flex-wrap gap-2">
            {venues.map((venue) => (
              <FilterPill
                key={venue.id}
                label={`${venue.venue_name} · ${venue.area}${venue.status !== "approved" ? ` (${v.pending})` : ""}`}
                active={venue.is_active}
                onClick={() => switchVenue(venue.id)}
              />
            ))}
          </div>
        )}

        {showForm && (
          <form onSubmit={addVenue} className="grid gap-2 rounded-marvi-lg border border-border bg-surface p-4 md:grid-cols-4">
            <input
              className="marvi-input"
              placeholder={v.venueName}
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
            />
            <input
              className="marvi-input"
              placeholder={v.areaPlaceholder}
              value={area}
              onChange={(e) => setArea(e.target.value)}
              required
            />
            <select className="marvi-input" value={category} onChange={(e) => setCategory(e.target.value)}>
              {(Object.keys(v.categories) as Array<keyof typeof v.categories>).map((key) => (
                <option key={key} value={key}>
                  {v.categories[key]}
                </option>
              ))}
            </select>
            <button type="submit" className="marvi-btn-secondary">
              {v.submitForReview}
            </button>
          </form>
        )}

        {message ? <SyncBanner tone="error" message={message} /> : null}

        {venues.length === 0 && !showForm ? <p className="text-sm text-muted">{v.noVenues}</p> : null}
      </div>
    </div>
  );
}
