import type { MetadataRoute } from "next";
import { SITE } from "@/config/site";

const MARKETING_PATHS = [
  "",
  "/creators",
  "/brands",
  "/faq",
  "/demo",
  "/contact",
  "/privacy",
  "/terms",
  "/community-guidelines",
  "/delete-account",
] as const;

export default function sitemap(): MetadataRoute.Sitemap {
  const lastModified = new Date();

  return MARKETING_PATHS.map((path) => ({
    url: `${SITE.url}${path}`,
    lastModified,
    changeFrequency: path === "" ? "weekly" : "monthly",
    priority: path === "" ? 1 : 0.7,
  }));
}
