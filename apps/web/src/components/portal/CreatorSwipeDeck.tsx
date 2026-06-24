"use client";

import { useState } from "react";
import { COLLABORATION_ICON_MAP } from "@/components/design/MarviIcons";
import { AvatarRing, EmptyState, SyncBanner } from "@/components/design/MarviUI";
import { IconSparkles } from "@/components/design/MarviIcons";
import type { PortalAdminDict } from "@/lib/i18n/portal-admin";
import { tReplace } from "@/lib/i18n/portal-admin";

type Candidate = {
  creator_id: string;
  full_name: string;
  instagram_handle: string;
  city: string;
  score: number;
  audience_count: number;
};

function initials(name: string): string {
  return name
    .split(/\s+/)
    .map((p) => p[0])
    .join("")
    .slice(0, 2);
}

export function CreatorSwipeDeck({
  initialCandidates,
  offerId,
  dict,
}: {
  initialCandidates: Candidate[];
  offerId?: string;
  dict: PortalAdminDict;
}) {
  const [candidates, setCandidates] = useState(initialCandidates);
  const [message, setMessage] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const c = dict.portal.creators;

  async function act(action: "shortlist" | "pass", creatorId: string) {
    setMessage(null);
    setBusy(true);
    try {
      const response = await fetch("/api/portal/creators", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action, creatorId, offerId }),
      });
      const data = await response.json();
      if (!response.ok) {
        setMessage(data.error ?? dict.common.actionFailed);
        return;
      }
      setCandidates((current) => current.filter((item) => item.creator_id !== creatorId));
    } finally {
      setBusy(false);
    }
  }

  const current = candidates[0];

  if (!current) {
    return (
      <EmptyState
        icon={<IconSparkles size={24} />}
        title={c.queueComplete}
        body={c.queueCompleteBody}
      />
    );
  }

  return (
    <div className="space-y-4">
      {message ? <SyncBanner tone="error" message={message} /> : null}

      <article className="marvi-card overflow-hidden p-0">
        <div className="bg-brand-gradient-vertical px-6 py-8 text-center">
          <div className="flex justify-center">
            <AvatarRing initials={initials(current.full_name)} size={80} />
          </div>
          <p className="mt-4 text-xs font-bold uppercase tracking-[0.14em] text-gold">{c.creatorMatch}</p>
          <h2 className="mt-1 font-serif text-2xl font-bold text-white">{current.full_name}</h2>
          <p className="mt-2 text-sm text-white/80">
            {current.instagram_handle} · {current.city}
          </p>
        </div>

        <div className="grid grid-cols-2 gap-px bg-border">
          <div className="bg-panel p-4 text-center">
            <p className="text-2xl font-bold text-rose">{current.score}</p>
            <p className="text-xs font-bold uppercase text-muted">{c.score}</p>
          </div>
          <div className="bg-panel p-4 text-center">
            <p className="text-2xl font-bold text-aubergine">
              {current.audience_count >= 1000
                ? `${Math.round(current.audience_count / 1000)}K`
                : current.audience_count}
            </p>
            <p className="text-xs font-bold uppercase text-muted">{c.audience}</p>
          </div>
        </div>

        <div className="flex gap-3 p-5">
          <button
            type="button"
            className="marvi-btn-secondary flex-1"
            disabled={busy}
            onClick={() => act("pass", current.creator_id)}
          >
            {c.pass}
          </button>
          <button
            type="button"
            className="marvi-btn-primary flex-1"
            disabled={busy}
            onClick={() => act("shortlist", current.creator_id)}
          >
            {c.shortlist}
          </button>
        </div>
      </article>

      <p className="text-center text-xs text-muted">
        {tReplace(c.moreInQueue, { count: candidates.length - 1 })}
        {offerId ? ` · ${tReplace(c.campaignRef, { id: offerId.slice(0, 8) })}` : ""}
      </p>
    </div>
  );
}

export function CollaborationModelPicker({
  value,
  onChange,
  dict,
}: {
  value: string;
  onChange: (v: string) => void;
  dict: PortalAdminDict;
}) {
  const models = [
    { id: "invitation", label: dict.portal.campaign.models.invitation },
    { id: "event", label: dict.portal.campaign.models.event },
    { id: "gift", label: dict.portal.campaign.models.gift },
    { id: "instant", label: dict.portal.campaign.models.instant },
  ] as const;

  return (
    <div className="grid grid-cols-2 gap-2">
      {models.map((model) => {
        const Icon = COLLABORATION_ICON_MAP[model.id];
        const active = value === model.id;
        return (
          <button
            key={model.id}
            type="button"
            onClick={() => onChange(model.id)}
            className={
              active
                ? "flex items-center gap-2 rounded-marvi bg-brand-gradient px-3 py-3 text-sm font-bold text-white shadow-rose"
                : "flex items-center gap-2 rounded-marvi border border-border bg-panel-elevated px-3 py-3 text-sm font-semibold text-graphite"
            }
          >
            <Icon size={16} />
            {model.label}
          </button>
        );
      })}
    </div>
  );
}
