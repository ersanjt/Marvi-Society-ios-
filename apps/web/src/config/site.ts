import { MARVI_URLS } from "@marvi/shared";
import { getPublicSiteUrl } from "@/config/env";

export const SITE = {
  name: "Marvi Society",
  tagline: "Istanbul's private creator × venue collaboration club",
  description:
    "Approved creators discover curated venue experiences. Venues receive structured social content. Operators curate quality and trust.",
  url: getPublicSiteUrl() || MARVI_URLS.site,
  email: "hello@marvisociety.com",
  supportEmail: "support@marvisociety.com",
  appStoreUrl: "#",
  playStoreUrl: "#",
} as const;

export const NAV_LINKS = [
  { href: "/brands", label: "Brands" },
  { href: "/creators", label: "Creators" },
  { href: "/faq", label: "FAQ" },
  { href: "/demo", label: "Get demo" },
] as const;

export const ADMIN_NAV = [
  { href: "/admin", label: "Queue" },
  { href: "/admin/users", label: "Users" },
  { href: "/admin/broadcast", label: "Broadcast" },
] as const;

export const PORTAL_NAV = [
  { href: "/portal/dashboard", label: "Dashboard" },
  { href: "/portal/campaigns/new", label: "New campaign" },
  { href: "/portal/creators", label: "Creators" },
  { href: "/portal/reviews", label: "Reviews" },
] as const;
