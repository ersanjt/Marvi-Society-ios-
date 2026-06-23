const PLACEHOLDER = "YOUR_PROJECT";

function read(name: string): string | undefined {
  const value = process.env[name]?.trim();
  return value || undefined;
}

export function isProduction(): boolean {
  return process.env.NODE_ENV === "production";
}

export function isSupabaseConfigured(): boolean {
  const url = read("NEXT_PUBLIC_SUPABASE_URL");
  const key = read("NEXT_PUBLIC_SUPABASE_ANON_KEY");
  return Boolean(url && key && !url.includes(PLACEHOLDER));
}

export function hasServiceRoleKey(): boolean {
  const key = read("SUPABASE_SERVICE_ROLE_KEY");
  return Boolean(key && key !== "your-service-role-key");
}

export function getPublicSiteUrl(): string {
  return read("NEXT_PUBLIC_SITE_URL") ?? "http://localhost:3000";
}

export function getSupabasePublicConfig() {
  return {
    url: read("NEXT_PUBLIC_SUPABASE_URL") ?? "",
    anonKey: read("NEXT_PUBLIC_SUPABASE_ANON_KEY") ?? "",
  };
}

/** Preview/demo mode — local dev only when Supabase is not wired. */
export function isPreviewMode(): boolean {
  return !isProduction() && !isSupabaseConfigured();
}

export function assertProductionConfig(): string | null {
  if (!isProduction()) return null;
  if (!isSupabaseConfigured()) {
    return "Supabase is not configured. Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY.";
  }
  if (!hasServiceRoleKey()) {
    return "SUPABASE_SERVICE_ROLE_KEY is required in production for admin API routes.";
  }
  return null;
}
