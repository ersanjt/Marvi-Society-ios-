import { createBrowserClient } from "@supabase/ssr";
import { getSupabasePublicConfig, isSupabaseConfigured } from "@/config/env";

export function createClient() {
  const { url, anonKey } = getSupabasePublicConfig();
  return createBrowserClient(url, anonKey);
}

export { isSupabaseConfigured };
