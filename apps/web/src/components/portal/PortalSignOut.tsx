"use client";

import { createClient, isSupabaseConfigured } from "@/lib/supabase/client";
import { useRouter } from "next/navigation";

export function PortalSignOut({ label }: { label: string }) {
  const router = useRouter();

  async function signOut() {
    if (isSupabaseConfigured()) {
      const supabase = createClient();
      await supabase.auth.signOut();
    }
    router.push("/portal/login");
    router.refresh();
  }

  return (
    <button type="button" onClick={signOut} className="text-muted hover:text-tomato">
      {label}
    </button>
  );
}
