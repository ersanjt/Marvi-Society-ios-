"use client";

import { useEffect } from "react";

/**
 * If a Supabase recovery link falls back to the Site URL root (e.g. when the
 * original redirect target was a custom scheme that the browser can't open),
 * the tokens land in the URL hash on whatever page Supabase bounced to. Detect
 * that case anywhere on the site and forward to the dedicated reset-password
 * page so the user can actually set a new password.
 */
export function RecoveryRedirectGuard() {
  useEffect(() => {
    const { hash, pathname } = window.location;
    if (!hash || pathname.startsWith("/auth/reset-password")) return;

    const params = new URLSearchParams(hash.replace(/^#/, ""));
    const isRecovery = params.get("type") === "recovery";
    const hasToken = Boolean(params.get("access_token"));

    if (isRecovery && hasToken) {
      window.location.replace(`/auth/reset-password${hash}`);
    }
  }, []);

  return null;
}
