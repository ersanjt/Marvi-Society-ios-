export const BILLING = {
  currency: "usd",
  partner: {
    id: "partner" as const,
    name: "Partner",
    amountCents: 14900,
    interval: "month" as const,
    liveCampaignLimit: null as number | null,
  },
  free: {
    id: "free" as const,
    name: "Free",
    amountCents: 0,
    liveCampaignLimit: 1,
  },
  boost: {
    id: "boost" as const,
    name: "Featured Boost",
    amountCents: 4900,
    days: 7,
  },
} as const;

export function formatUsd(cents: number): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 0,
  }).format(cents / 100);
}
