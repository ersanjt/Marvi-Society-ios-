import Link from "next/link";
import { SITE } from "@/lib/constants";

type StoreDownloadButtonsProps = {
  appStoreLabel: string;
  playStoreLabel: string;
  className?: string;
  primaryAppStore?: boolean;
};

/** Shared App Store + Google Play CTAs for marketing pages. */
export function StoreDownloadButtons({
  appStoreLabel,
  playStoreLabel,
  className = "",
  primaryAppStore = true,
}: StoreDownloadButtonsProps) {
  return (
    <div className={`flex flex-wrap gap-3 ${className}`.trim()}>
      <a
        href={SITE.appStoreUrl}
        className={primaryAppStore ? "marvi-btn-primary" : "marvi-btn-secondary"}
        target="_blank"
        rel="noopener noreferrer"
      >
        {appStoreLabel}
      </a>
      {SITE.playStoreUrl ? (
        <a
          href={SITE.playStoreUrl}
          className={primaryAppStore ? "marvi-btn-secondary" : "marvi-btn-primary"}
          target="_blank"
          rel="noopener noreferrer"
        >
          {playStoreLabel}
        </a>
      ) : null}
    </div>
  );
}

type OpenInAppButtonProps = {
  href: string;
  label: string;
  className?: string;
};

export function OpenInAppButton({ href, label, className = "" }: OpenInAppButtonProps) {
  return (
    <a href={href} className={`marvi-btn-primary ${className}`.trim()}>
      {label}
    </a>
  );
}

export function InviteFallbackLinks({
  inviteDeepLink,
  openLabel,
  appStoreLabel,
  playStoreLabel,
}: {
  inviteDeepLink: string;
  openLabel: string;
  appStoreLabel: string;
  playStoreLabel: string;
}) {
  return (
    <div className="flex flex-col items-stretch gap-3 sm:items-center">
      <OpenInAppButton href={inviteDeepLink} label={openLabel} className="inline-flex justify-center" />
      <StoreDownloadButtons
        appStoreLabel={appStoreLabel}
        playStoreLabel={playStoreLabel}
        primaryAppStore
        className="justify-center"
      />
      <Link href="/creators" className="text-sm font-semibold text-rose hover:underline">
        Learn more for creators
      </Link>
    </div>
  );
}
