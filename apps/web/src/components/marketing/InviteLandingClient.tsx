"use client";

import { useEffect } from "react";
import { BrandLockup } from "@/components/brand/BrandMark";
import { InviteFallbackLinks } from "@/components/marketing/StoreDownloadButtons";
import { MarviScreen } from "@/components/design/MarviUI";

type InviteLandingClientProps = {
  code: string;
  title: string;
  subtitle: string;
  openLabel: string;
  codeLabel: string;
  appStoreLabel: string;
  playStoreLabel: string;
};

export function InviteLandingClient({
  code,
  title,
  subtitle,
  openLabel,
  codeLabel,
  appStoreLabel,
  playStoreLabel,
}: InviteLandingClientProps) {
  const deepLink = code
    ? `marvisociety://invite?code=${encodeURIComponent(code)}`
    : "marvisociety://invite";

  useEffect(() => {
    if (!code) return;
    try {
      localStorage.setItem("marvi_pending_invite_code", code);
    } catch {
      /* ignore */
    }
    const timer = window.setTimeout(() => {
      window.location.href = deepLink;
    }, 250);
    return () => window.clearTimeout(timer);
  }, [code, deepLink]);

  return (
    <MarviScreen className="min-h-[70vh] border-b border-border">
      <div className="mx-auto flex max-w-lg flex-col items-center px-4 py-20 text-center md:px-6">
        <BrandLockup subtitle="Invite" size={48} />
        <h1 className="mt-8 font-serif text-3xl font-bold text-ink md:text-4xl">{title}</h1>
        <p className="mt-4 text-muted">{subtitle}</p>
        {code ? (
          <div className="mt-8 w-full rounded-marvi border border-border bg-panel px-4 py-5">
            <p className="text-xs font-bold uppercase tracking-[0.14em] text-gold">{codeLabel}</p>
            <p className="mt-2 font-mono text-2xl font-bold tracking-widest text-ink">{code}</p>
          </div>
        ) : null}
        <div className="mt-8 w-full">
          <InviteFallbackLinks
            inviteDeepLink={deepLink}
            openLabel={openLabel}
            appStoreLabel={appStoreLabel}
            playStoreLabel={playStoreLabel}
          />
        </div>
      </div>
    </MarviScreen>
  );
}
