"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { BrandLockup } from "@/components/brand/BrandMark";
import { MarviScreen, SyncBanner } from "@/components/design/MarviUI";
import { createClient } from "@/lib/supabase/client";
import { SITE } from "@/config/site";

type Phase = "loading" | "form" | "success" | "error";

export function ResetPasswordForm({ locale }: { locale: "en" | "tr" }) {
  const isTr = locale === "tr";
  const [phase, setPhase] = useState<Phase>("loading");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const supabase = createClient();

    async function initSession() {
      const params = new URLSearchParams(window.location.search);
      const code = params.get("code");

      if (code) {
        const { error: exchangeError } = await supabase.auth.exchangeCodeForSession(code);
        if (exchangeError) {
          setError(exchangeError.message);
          setPhase("error");
          return;
        }
        setPhase("form");
        return;
      }

      const hash = window.location.hash.replace(/^#/, "");
      if (hash) {
        const hashParams = new URLSearchParams(hash);
        const accessToken = hashParams.get("access_token");
        const refreshToken = hashParams.get("refresh_token");
        const type = hashParams.get("type");

        if (accessToken && refreshToken && type === "recovery") {
          const { error: sessionError } = await supabase.auth.setSession({
            access_token: accessToken,
            refresh_token: refreshToken,
          });
          if (sessionError) {
            setError(sessionError.message);
            setPhase("error");
            return;
          }
          window.history.replaceState({}, "", window.location.pathname);
          setPhase("form");
          return;
        }
      }

      const {
        data: { session },
      } = await supabase.auth.getSession();
      if (session) {
        setPhase("form");
        return;
      }

      setError(
        isTr
          ? "Bağlantı geçersiz veya süresi dolmuş. Uygulamadan tekrar şifre sıfırlama isteyin."
          : "This link is invalid or expired. Request a new reset link from the app."
      );
      setPhase("error");
    }

    const { data: listener } = supabase.auth.onAuthStateChange((event) => {
      if (event === "PASSWORD_RECOVERY") {
        setPhase("form");
      }
    });

    initSession();

    return () => {
      listener.subscription.unsubscribe();
    };
  }, [isTr]);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");

    if (password.length < 8) {
      setError(isTr ? "Şifre en az 8 karakter olmalı." : "Password must be at least 8 characters.");
      return;
    }
    if (password !== confirm) {
      setError(isTr ? "Şifreler eşleşmiyor." : "Passwords do not match.");
      return;
    }

    setBusy(true);
    const supabase = createClient();
    const { error: updateError } = await supabase.auth.updateUser({ password });
    setBusy(false);

    if (updateError) {
      setError(updateError.message);
      return;
    }

    await supabase.auth.signOut();
    setPhase("success");
  }

  if (phase === "loading") {
    return <p className="mt-8 text-sm text-muted">{isTr ? "Yükleniyor…" : "Loading…"}</p>;
  }

  if (phase === "success") {
    return (
      <div className="marvi-card mt-8 text-center">
        <p className="font-serif text-2xl font-bold text-ink">
          {isTr ? "Şifre güncellendi" : "Password updated"}
        </p>
        <p className="mt-3 text-sm text-muted">
          {isTr
            ? "Marvi Society uygulamasını açın ve yeni şifrenizle giriş yapın."
            : "Open the Marvi Society app and sign in with your new password."}
        </p>
        <p className="mt-6 text-xs text-muted">{SITE.email}</p>
      </div>
    );
  }

  if (phase === "error") {
    return (
      <div className="mt-8 space-y-4">
        <SyncBanner tone="error" message={error} />
        <p className="text-center text-sm text-muted">
          {isTr ? "Uygulamada" : "In the app"}:{" "}
          <span className="text-ink">{isTr ? "Giriş → Şifremi unuttum" : "Sign in → Forgot password"}</span>
        </p>
      </div>
    );
  }

  return (
    <form className="marvi-card mt-8 space-y-4" onSubmit={onSubmit}>
      <p className="text-sm text-muted">
        {isTr ? "Yeni şifrenizi belirleyin (en az 8 karakter)." : "Choose a new password (min. 8 characters)."}
      </p>
      <label className="block text-sm font-semibold text-ink">
        {isTr ? "Yeni şifre" : "New password"}
        <input
          type="password"
          required
          minLength={8}
          className="mt-1 marvi-input"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          autoComplete="new-password"
        />
      </label>
      <label className="block text-sm font-semibold text-ink">
        {isTr ? "Şifreyi tekrarla" : "Confirm password"}
        <input
          type="password"
          required
          minLength={8}
          className="mt-1 marvi-input"
          value={confirm}
          onChange={(e) => setConfirm(e.target.value)}
          autoComplete="new-password"
        />
      </label>
      {error ? <SyncBanner tone="error" message={error} /> : null}
      <button type="submit" className="marvi-btn-primary w-full" disabled={busy}>
        {busy ? (isTr ? "Kaydediliyor…" : "Saving…") : isTr ? "Şifreyi kaydet" : "Save password"}
      </button>
    </form>
  );
}
