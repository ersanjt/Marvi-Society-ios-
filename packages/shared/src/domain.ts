/** Cross-platform domain constants (mirror Supabase enums + OpenAPI). */
export const USER_ROLES = ["creator", "venue", "admin"] as const;
export const MEMBERSHIP_STATUSES = ["under_review", "approved", "paused"] as const;
export const COLLABORATION_MODELS = ["invitation", "event", "gift", "instant"] as const;
export const OFFER_CATEGORIES = [
  "dining",
  "nightlife",
  "wellness",
  "beauty",
  "fitness",
  "retail",
] as const;
export const REFERRAL_CODES = {
  creatorDefault: "MARVI-IST",
  venueDefault: "MARVI2026",
} as const;
