"use client";

import { createClient, isSupabaseConfigured } from "@/lib/supabase/client";
import { isPreviewMode } from "@/config/env";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useState } from "react";

function safeNextPath(value: string | null): string {
  if (!value || !value.startsWith("/") || value.startsWith("//")) {
    return "/portal/dashboard";
  }
  return value;
}

export function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const nextPath = safeNextPath(searchParams.get("next"));
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const previewMode = isPreviewMode();

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setLoading(true);
    setError("");
    const form = new FormData(e.currentTarget);
    const email = String(form.get("email"));
    const password = String(form.get("password"));

    if (previewMode) {
      router.push(nextPath);
      return;
    }

    if (!isSupabaseConfigured()) {
      setError("Sign-in is unavailable until Supabase is configured.");
      setLoading(false);
      return;
    }

    const supabase = createClient();
    const { error: authError } = await supabase.auth.signInWithPassword({ email, password });
    setLoading(false);

    if (authError) {
      setError(authError.message);
      return;
    }
    router.push(nextPath);
    router.refresh();
  }

  return (
    <form className="mt-8 space-y-4" onSubmit={onSubmit}>
      <label className="block text-sm font-semibold">
        Email
        <input name="email" type="email" required className="mt-1 w-full rounded-marvi border border-border bg-panel-elevated px-3 py-2 text-ink outline-none ring-rose/30 focus:ring-2" />
      </label>
      <label className="block text-sm font-semibold">
        Password
        <input name="password" type="password" required className="mt-1 w-full rounded-marvi border border-border bg-panel-elevated px-3 py-2 text-ink outline-none ring-rose/30 focus:ring-2" />
      </label>
      {error ? <p className="text-sm text-tomato">{error}</p> : null}
      <button type="submit" className="marvi-btn-primary w-full" disabled={loading}>
        {loading ? "Signing in…" : "Sign in"}
      </button>
      <p className="text-center text-xs text-muted">
        {previewMode ? (
          <>
            Local preview mode — no Supabase required.{" "}
            <Link href="/demo" className="marvi-link">
              Request a demo
            </Link>
          </>
        ) : (
          <>
            Need access?{" "}
            <Link href="/demo" className="marvi-link">
              Request a demo
            </Link>
          </>
        )}
      </p>
    </form>
  );
}
