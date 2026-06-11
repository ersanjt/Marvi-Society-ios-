import { createServerClient, type CookieOptions } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

async function getUser(request: NextRequest, response: NextResponse) {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseKey || supabaseUrl.includes("YOUR_PROJECT")) {
    return { user: null, response, configured: false };
  }

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

  const { data: { user } } = await supabase.auth.getUser();
  return { user, response, configured: true, supabase };
}

export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request });
  const { user, configured, supabase } = await getUser(request, response);

  if (request.nextUrl.pathname.startsWith("/portal") && !request.nextUrl.pathname.startsWith("/portal/login")) {
    if (configured && !user) {
      return NextResponse.redirect(new URL("/portal/login", request.url));
    }
  }

  if (request.nextUrl.pathname.startsWith("/admin") || request.nextUrl.pathname.startsWith("/api/admin")) {
    if (configured) {
      if (!user) {
        return NextResponse.redirect(new URL("/portal/login", request.url));
      }

      if (supabase) {
        const { data: profile } = await supabase
          .from("profiles")
          .select("role")
          .eq("id", user.id)
          .maybeSingle();

        if (profile?.role !== "admin") {
          if (request.nextUrl.pathname.startsWith("/api/admin")) {
            return NextResponse.json({ error: "Admin access required" }, { status: 403 });
          }
          return NextResponse.redirect(new URL("/portal/dashboard", request.url));
        }
      }
    }
  }

  return response;
}

export const config = {
  matcher: ["/portal/:path*", "/admin/:path*", "/api/admin/:path*"],
};
