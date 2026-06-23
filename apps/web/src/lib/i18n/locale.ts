import { cookies, headers } from "next/headers";
import { type Locale, getDictionary } from "./dictionaries";
import { inferLocaleFromHeaders } from "./infer-locale";

export async function getLocale(): Promise<Locale> {
  const cookieStore = await cookies();
  const value = cookieStore.get("locale")?.value;
  if (value === "tr" || value === "en") {
    return value;
  }

  const headerStore = await headers();
  return inferLocaleFromHeaders(headerStore);
}

export async function getI18n() {
  const locale = await getLocale();
  return { locale, dict: getDictionary(locale) };
}
