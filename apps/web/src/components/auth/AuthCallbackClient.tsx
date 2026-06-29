"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { BrandLockup } from "@/components/brand/BrandMark";
import { MarviScreen, SyncBanner } from "@/components/design/MarviUI";
import { createClient } from "@/lib/supabase/client";

/** Only allow internal absolute paths to prevent open-redirect phishing. */
function safeNextPath(value: string | null): string {
  if (!value || !value.startsWith("/") || value.startsWith("//")) {
    return "/portal/dashboard";
  }
  return value;
}

export function AuthCallbackClient() {
  const [status, setStatus] = useState<"loading" | "error" | "ios-bounce">("loading");
  const [message, setMessage] = useState("");

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);

    // iOS OAuth: bounce HTTPS callback → app deep link so ASWebAuthenticationSession can finish.
    if (params.get("client") === "ios") {
      setStatus("ios-bounce");

      const code = params.get("code");
      const error = params.get("error");
      const errorDescription = params.get("error_description");
      const hash = window.location.hash || "";
      let deepLink = "marvisociety://auth/callback";

      if (code) {
        deepLink += `?code=${encodeURIComponent(code)}`;
      } else if (error) {
        const qs = new URLSearchParams();
        qs.set("error", error);
        if (errorDescription) qs.set("error_description", errorDescription);
        deepLink += `?${qs.toString()}`;
      }

      const target = deepLink + hash;
      window.location.replace(target);
      // Fallback if replace does not hand off to the native app sheet.
      const fallback = window.setTimeout(() => {
        window.location.href = target;
      }, 600);
      return () => window.clearTimeout(fallback);
    }

    const supabase = createClient();

    async function run() {
      const code = params.get("code");
      const next = safeNextPath(params.get("next"));

      if (code) {
        const { error } = await supabase.auth.exchangeCodeForSession(code);
        if (error) {
          setMessage(error.message);
          setStatus("error");
          return;
        }
        window.location.href = next;
        return;
      }

      const hash = window.location.hash.replace(/^#/, "");
      if (hash) {
        const hashParams = new URLSearchParams(hash);
        const accessToken = hashParams.get("access_token");
        const refreshToken = hashParams.get("refresh_token");
        if (accessToken && refreshToken) {
          const { error } = await supabase.auth.setSession({
            access_token: accessToken,
            refresh_token: refreshToken,
          });
          if (error) {
            setMessage(error.message);
            setStatus("error");
            return;
          }
          window.location.href = next;
          return;
        }
      }

      setMessage("Invalid or expired sign-in link.");
      setStatus("error");
    }

    run();
  }, []);

  return (
    <MarviScreen className="min-h-screen">
      <div className="mx-auto flex min-h-screen max-w-md flex-col items-center justify-center px-4 py-16 text-center">
        <BrandLockup subtitle="Authentication" size={48} />
        {status === "loading" ? <p className="mt-8 text-sm text-muted">Signing you in…</p> : null}
        {status === "ios-bounce" ? (
          <p className="mt-8 text-sm text-muted">Returning to Marvi Society app…</p>
        ) : null}
        {status === "error" ? (
          <div className="mt-8 w-full">
            <SyncBanner tone="error" message={message} />
            <Link href="/portal/login" className="marvi-btn-primary mt-6 inline-flex">
              Go to login
            </Link>
          </div>
        ) : null}
      </div>
    </MarviScreen>
  );
}
