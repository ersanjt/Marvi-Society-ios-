import type { Locale } from "@/lib/i18n/dictionaries";
import { getPortalAdminDict } from "@/lib/i18n/portal-admin";

export type StatusTone = "rose" | "emerald" | "gold" | "tomato" | "aubergine" | "blue" | "muted";

export const TONE_CLASS: Record<StatusTone, string> = {
  rose: "bg-rose/15 text-rose",
  emerald: "bg-emerald/15 text-emerald",
  gold: "bg-gold/15 text-gold",
  tomato: "bg-tomato/15 text-tomato",
  aubergine: "bg-aubergine/15 text-aubergine",
  blue: "bg-blue/15 text-blue",
  muted: "bg-panel-elevated text-muted",
};

export function offerStatusTone(status: string): StatusTone {
  switch (status) {
    case "live":
      return "emerald";
    case "review":
      return "gold";
    case "draft":
      return "muted";
    case "paused":
      return "tomato";
    default:
      return "muted";
  }
}

export function proofStatusTone(status: string): StatusTone {
  switch (status) {
    case "approved":
      return "emerald";
    case "pending":
      return "gold";
    case "rejected":
      return "tomato";
    default:
      return "muted";
  }
}

export function bookingStageTone(stage: string): StatusTone {
  switch (stage) {
    case "confirmed":
    case "visited":
      return "emerald";
    case "requested":
      return "gold";
    case "cancelled":
      return "tomato";
    default:
      return "blue";
  }
}

export function formatStatusLabel(value: string, locale: Locale = "en"): string {
  const key = value.toLowerCase();
  const labels = getPortalAdminDict(locale).status as Record<string, string>;
  if (labels[key]) return labels[key];
  return value.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

export function taskTypeTone(type: string): StatusTone {
  switch (type) {
    case "creator_application":
      return "rose";
    case "venue_application":
      return "aubergine";
    case "campaign_review":
      return "gold";
    case "proof_review":
      return "blue";
    default:
      return "muted";
  }
}

export function membershipStatusTone(status: string | null): StatusTone {
  switch (status) {
    case "approved":
      return "emerald";
    case "under_review":
      return "gold";
    case "paused":
      return "tomato";
    default:
      return "muted";
  }
}
