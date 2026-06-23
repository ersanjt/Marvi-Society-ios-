"use client";

import { useState } from "react";

export function AdminBroadcastForm() {
  const [lat, setLat] = useState("41.015");
  const [lng, setLng] = useState("28.979");
  const [radiusKm, setRadiusKm] = useState("3");
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [message, setMessage] = useState("");

  async function submit() {
    setMessage("");
    const response = await fetch("/api/admin/broadcast", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        lat: Number(lat),
        lng: Number(lng),
        radius_km: Number(radiusKm),
        title,
        body,
      }),
    });
    const json = await response.json();
    setMessage(response.ok ? json.message : json.error ?? "Request failed");
  }

  return (
    <div className="marvi-card space-y-4 p-5">
      <div className="grid gap-3 md:grid-cols-3">
        <label className="space-y-1 text-sm">
          <span className="font-semibold text-muted">Latitude</span>
          <input className="marvi-input w-full" value={lat} onChange={(e) => setLat(e.target.value)} />
        </label>
        <label className="space-y-1 text-sm">
          <span className="font-semibold text-muted">Longitude</span>
          <input className="marvi-input w-full" value={lng} onChange={(e) => setLng(e.target.value)} />
        </label>
        <label className="space-y-1 text-sm">
          <span className="font-semibold text-muted">Radius (km)</span>
          <input className="marvi-input w-full" value={radiusKm} onChange={(e) => setRadiusKm(e.target.value)} />
        </label>
      </div>

      <input className="marvi-input w-full" placeholder="Title" value={title} onChange={(e) => setTitle(e.target.value)} />
      <textarea className="marvi-input min-h-28 w-full" placeholder="Message" value={body} onChange={(e) => setBody(e.target.value)} />

      <button className="marvi-btn-primary" onClick={submit}>
        Send area broadcast
      </button>

      {message ? <p className="text-sm font-semibold text-emerald">{message}</p> : null}
    </div>
  );
}
