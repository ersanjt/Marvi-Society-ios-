"use client";

import { useState } from "react";

const STATUSES = ["new", "contacted", "qualified", "won", "closed"] as const;

export function LeadStatusForm({
  id,
  current,
  labels,
}: {
  id: string;
  current: string;
  labels: { save: string; failed: string };
}) {
  const [status, setStatus] = useState(current);
  const [message, setMessage] = useState("");

  async function onSave() {
    setMessage("");
    const res = await fetch(`/api/admin/leads/${id}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ status }),
    });
    const data = await res.json();
    setMessage(res.ok ? labels.save : data.error ?? labels.failed);
  }

  return (
    <div className="flex flex-wrap items-center gap-2">
      <select
        className="rounded-marvi border border-border bg-panel-elevated px-3 py-2 text-sm"
        value={status}
        onChange={(e) => setStatus(e.target.value)}
      >
        {STATUSES.map((value) => (
          <option key={value} value={value}>
            {value}
          </option>
        ))}
      </select>
      <button type="button" className="marvi-btn-secondary text-sm" onClick={onSave}>
        {labels.save}
      </button>
      {message ? <span className="text-xs text-muted">{message}</span> : null}
    </div>
  );
}
