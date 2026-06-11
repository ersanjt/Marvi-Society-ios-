export async function trackWebEvent(name: string, properties: Record<string, string | number> = {}) {
  if (typeof window === "undefined") return;

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
