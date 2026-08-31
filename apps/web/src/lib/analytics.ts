export const COOKIE_CONSENT_KEY = "marvi_cookie_consent";

export function hasAnalyticsConsent(): boolean {
  if (typeof window === "undefined") return false;
  return window.localStorage.getItem(COOKIE_CONSENT_KEY) === "all";
}

export async function trackWebEvent(name: string, properties: Record<string, string | number> = {}) {
  if (typeof window === "undefined") return;
  if (!hasAnalyticsConsent()) return;

  try {
    await fetch("/api/analytics", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name, properties }),
    });
  } catch {
    // analytics should never block UX
  }
}
