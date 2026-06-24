import { createServerClient, type CookieOptions } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { isProduction, isSupabaseConfigured } from "@/config/env";
import { inferLocaleFromRequest } from "@/lib/i18n/infer-locale";

function applyLocaleCookie(request: NextRequest, response: NextResponse) {
  if (request.cookies.get("locale")?.value) {
    return;
  }
  const locale = inferLocaleFromRequest(request);
  response.cookies.set("locale", locale, {
    path: "/",
    maxAge: 60 * 60 * 24 * 365,
    sameSite: "lax",
  });
}

function copyCookies(from: NextResponse, to: NextResponse) {
  from.cookies.getAll().forEach((cookie) => {
    to.cookies.set(cookie.name, cookie.value);
  });
}

function redirectWithSession(
  request: NextRequest,
  baseResponse: NextResponse,
  url: URL | string
) {
  const redirect = typeof url === "string" ? NextResponse.redirect(url) : NextResponse.redirect(url);
  copyCookies(baseResponse, redirect);
  applyLocaleCookie(request, redirect);
  return redirect;
}

function loginRedirect(request: NextRequest, nextPath: string, baseResponse: NextResponse) {
  const url = new URL("/portal/login", request.url);
  url.searchParams.set("next", nextPath);
  return redirectWithSession(request, baseResponse, url);
}

async function getUser(request: NextRequest, response: NextResponse) {
  if (!isSupabaseConfigured()) {
    return { user: null, response, configured: false };
  }

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

  const supabase = createServerClient(supabaseUrl, supabaseKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet: { name: string; value: string; options: CookieOptions }[]) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
        cookiesToSet.forEach(({ name, value, options }) =>
          response.cookies.set(name, value, options)
        );
      },
    },
  });

  const {
    data: { user },
  } = await supabase.auth.getUser();
  return { user, response, configured: true, supabase };
}

export async function middleware(request: NextRequest) {
  const pathname = request.nextUrl.pathname;

  // iOS OAuth: instant redirect to app deep link (before any React / portal session).
  if (pathname === "/auth/ios-callback") {
    const deepLink = new URL("marvisociety://auth/callback");
    request.nextUrl.searchParams.forEach((value, key) => {
      deepLink.searchParams.set(key, value);
    });
    return NextResponse.redirect(deepLink.toString());
  }

  const isProtectedPortal =
    pathname.startsWith("/portal") && !pathname.startsWith("/portal/login");
  const isProtectedAdmin =
    pathname.startsWith("/admin") || pathname.startsWith("/api/admin");

  if (isProduction() && !isSupabaseConfigured() && (isProtectedPortal || isProtectedAdmin)) {
    if (pathname.startsWith("/api/")) {
      const response = NextResponse.json({ error: "Supabase is not configured" }, { status: 503 });
      applyLocaleCookie(request, response);
      return response;
    }
    return redirectWithSession(
      request,
      NextResponse.next({ request }),
      new URL("/contact?error=configuration", request.url)
    );
  }

  let response = NextResponse.next({ request });
  applyLocaleCookie(request, response);
  const { user, configured, supabase } = await getUser(request, response);

  if (isProtectedPortal) {
    if (configured && !user) {
      return loginRedirect(request, pathname, response);
    }
  }

  if (isProtectedAdmin) {
    if (configured) {
      if (!user) {
        return loginRedirect(request, pathname, response);
      }

      if (supabase) {
        const { data: profile } = await supabase
          .from("profiles")
          .select("role")
          .eq("id", user.id)
          .maybeSingle();

        if (profile?.role !== "admin") {
          if (pathname.startsWith("/api/admin")) {
            const denied = NextResponse.json({ error: "Admin access required" }, { status: 403 });
            copyCookies(response, denied);
            applyLocaleCookie(request, denied);
            return denied;
          }
          return redirectWithSession(
            request,
            response,
            new URL("/portal/dashboard", request.url)
          );
        }
      }
    }
  }

  return response;
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)",
  ],
};
