"use client";

import { useState } from "react";

export function CheckoutButton({
  kind,
  offerId,
  label,
  className = "marvi-btn-primary",
  disabledLabel = "Opening checkout…",
}: {
  kind: "partner" | "boost";
  offerId?: string;
  label: string;
  className?: string;
  disabledLabel?: string;
}) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  async function onClick() {
    setBusy(true);
    setError("");
    try {
      const res = await fetch("/api/stripe/checkout", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ kind, offerId }),
      });
      const data = await res.json();
      if (!res.ok || !data.url) {
        setError(data.error ?? "Checkout failed");
        setBusy(false);
        return;
      }
      window.location.href = data.url;
    } catch {
      setError("Checkout failed");
      setBusy(false);
    }
  }

  return (
    <div className="space-y-2">
      <button type="button" className={className} disabled={busy} onClick={onClick}>
        {busy ? disabledLabel : label}
      </button>
      {error ? <p className="text-sm text-tomato">{error}</p> : null}
    </div>
  );
}

export function BillingPortalButton({ label }: { label: string }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  async function onClick() {
    setBusy(true);
    setError("");
    try {
      const res = await fetch("/api/stripe/portal", { method: "POST" });
      const data = await res.json();
      if (!res.ok || !data.url) {
        setError(data.error ?? "Could not open billing portal");
        setBusy(false);
        return;
      }
      window.location.href = data.url;
    } catch {
      setError("Could not open billing portal");
      setBusy(false);
    }
  }

  return (
    <div className="space-y-2">
      <button type="button" className="marvi-btn-secondary" disabled={busy} onClick={onClick}>
        {busy ? "…" : label}
      </button>
      {error ? <p className="text-sm text-tomato">{error}</p> : null}
    </div>
  );
}
