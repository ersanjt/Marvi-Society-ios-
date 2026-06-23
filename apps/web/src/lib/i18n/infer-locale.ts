import type { NextRequest } from "next/server";
import { type Locale } from "./dictionaries";

function countryFromHeaders(headers: Headers): string | null {
  return (
    headers.get("x-vercel-ip-country") ??
    headers.get("cf-ipcountry")
  );
}

function localeFromCountryAndLanguage(country: string | null, acceptLanguage: string | null): Locale {
  if (country?.toUpperCase() === "TR") {
    return "tr";
  }

  const primary = acceptLanguage?.split(",")[0]?.trim().toLowerCase() ?? "";
  if (primary.startsWith("tr")) {
    return "tr";
  }

  return "en";
}

/** Turkey → Turkish; everywhere else → English unless user chose manually (locale cookie). */
export function inferLocaleFromRequest(request: NextRequest): Locale {
  return localeFromCountryAndLanguage(
    countryFromHeaders(request.headers),
    request.headers.get("accept-language")
  );
}

export function inferLocaleFromHeaders(headers: Headers): Locale {
  return localeFromCountryAndLanguage(
    countryFromHeaders(headers),
    headers.get("accept-language")
  );
}
