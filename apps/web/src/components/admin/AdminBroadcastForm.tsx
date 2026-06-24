"use client";

import { useState } from "react";
import { IconMapPin } from "@/components/design/MarviIcons";
import { SyncBanner } from "@/components/design/MarviUI";
import type { PortalAdminDict } from "@/lib/i18n/portal-admin";

const ISTANBUL_PRESETS = [
  { label: "Karaköy", lat: "41.0256", lng: "28.9744" },
  { label: "Nişantaşı", lat: "41.0522", lng: "28.9948" },
  { label: "Bebek", lat: "41.0775", lng: "29.0433" },
  { label: "Kadıköy", lat: "40.9903", lng: "29.0257" },
];

export function AdminBroadcastForm({ dict }: { dict: PortalAdminDict }) {
  const [lat, setLat] = useState("41.015");
  const [lng, setLng] = useState("28.979");
  const [radiusKm, setRadiusKm] = useState("3");
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [message, setMessage] = useState("");
  const [tone, setTone] = useState<"success" | "error">("success");
  const b = dict.admin.broadcast;
  const c = dict.common;

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
    if (response.ok) {
      setTone("success");
      setMessage(json.message ?? b.broadcastSent);
    } else {
      setTone("error");
      setMessage(json.error ?? c.requestFailed);
    }
  }

  return (
    <div className="space-y-4">
      <div className="marvi-card space-y-4">
        <div className="flex items-center gap-2 text-rose">
          <IconMapPin size={18} />
          <p className="text-sm font-bold text-ink">{b.istanbulPresets}</p>
        </div>
        <div className="flex flex-wrap gap-2">
          {ISTANBUL_PRESETS.map((preset) => (
            <button
              key={preset.label}
              type="button"
              className="marvi-pill border border-border bg-panel-elevated text-graphite transition hover:border-rose/30"
              onClick={() => {
                setLat(preset.lat);
                setLng(preset.lng);
              }}
            >
              {preset.label}
            </button>
          ))}
        </div>

        <div className="grid gap-3 md:grid-cols-3">
          <label className="space-y-1 text-sm">
            <span className="font-semibold text-muted">{b.latitude}</span>
            <input className="marvi-input w-full" value={lat} onChange={(e) => setLat(e.target.value)} />
          </label>
          <label className="space-y-1 text-sm">
            <span className="font-semibold text-muted">{b.longitude}</span>
            <input className="marvi-input w-full" value={lng} onChange={(e) => setLng(e.target.value)} />
          </label>
          <label className="space-y-1 text-sm">
            <span className="font-semibold text-muted">{b.radiusKm}</span>
            <input className="marvi-input w-full" value={radiusKm} onChange={(e) => setRadiusKm(e.target.value)} />
          </label>
        </div>

        <input className="marvi-input w-full" placeholder={b.notificationTitle} value={title} onChange={(e) => setTitle(e.target.value)} />
        <textarea
          className="marvi-input min-h-28 w-full"
          placeholder={b.messageBody}
          value={body}
          onChange={(e) => setBody(e.target.value)}
        />

        <button type="button" className="marvi-btn-primary w-full" onClick={submit}>
          {b.sendBroadcast}
        </button>
      </div>

      {message ? <SyncBanner tone={tone} message={message} /> : null}
    </div>
  );
}
