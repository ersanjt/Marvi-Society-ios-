"use client";

import { createClient, isSupabaseConfigured } from "@/lib/supabase/client";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";

export function LoginForm() {
  const router = useRouter();
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setLoading(true);
    setError("");
    const form = new FormData(e.currentTarget);
    const email = String(form.get("email"));
    const password = String(form.get("password"));

    if (!isSupabaseConfigured()) {
      router.push("/portal/dashboard");
      return;
    }

    const supabase = createClient();
    const { error: authError } = await supabase.auth.signInWithPassword({ email, password });
    setLoading(false);

    if (authError) {
      setError(authError.message);
      return;
    }
    router.push("/portal/dashboard");
    router.refresh();
  }

  return (
    <form className="mt-8 space-y-4" onSubmit={onSubmit}>
      <label className="block text-sm font-semibold">
        Email
        <input name="email" type="email" required className="mt-1 w-full rounded-marvi border border-black/10 px-3 py-2" />
      </label>
      <label className="block text-sm font-semibold">
        Password
        <input name="password" type="password" required className="mt-1 w-full rounded-marvi border border-black/10 px-3 py-2" />
      </label>
      {error ? <p className="text-sm text-tomato">{error}</p> : null}
      <button type="submit" className="marvi-btn-primary w-full" disabled={loading}>
        {loading ? "Signing in…" : "Sign in"}
      </button>
      <p className="text-center text-xs text-muted">
        Preview mode works without Supabase env.{" "}
        <Link href="/demo" className="font-bold text-emerald">Request a demo</Link>
      </p>
    </form>
  );
}
