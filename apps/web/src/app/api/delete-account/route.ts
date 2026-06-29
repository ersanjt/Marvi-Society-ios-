import { createClient } from "@supabase/supabase-js";
import { NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { isProduction, isSupabaseConfigured } from "@/config/env";
import { checkRateLimit } from "@/lib/security/rateLimit";

/** Step 1: send email OTP via Supabase Auth (requires SMTP in Supabase dashboard). */
export async function POST(request: Request) {
  const rate = checkRateLimit(request, "delete-account", { limit: 3, windowMs: 60 * 60 * 1000 });
  if (!rate.ok) {
    return NextResponse.json(
      { error: "Too many verification requests. Please try again later." },
      { status: 429, headers: { "Retry-After": String(rate.retryAfter) } }
    );
  }

  const { email } = await request.json();
  const normalized = String(email ?? "").trim().toLowerCase();

  if (!normalized) {
    return NextResponse.json({ error: "Email required" }, { status: 400 });
  }

  if (!isSupabaseConfigured()) {
    if (isProduction()) {
      return NextResponse.json(
        { error: "Account deletion is temporarily unavailable. Email support@marvisociety.com." },
        { status: 503 }
      );
    }
    return NextResponse.json({
      ok: true,
      mode: "preview",
      message: "Configure Supabase env vars for production deletion flow.",
    });
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

  const supabase = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { error } = await supabase.auth.signInWithOtp({
    email: normalized,
    options: { shouldCreateUser: false },
  });

  if (error) {
    const message = error.message.toLowerCase().includes("signups not allowed")
      ? "No account found for this email."
      : error.message;
    return NextResponse.json({ error: message }, { status: 400 });
  }

  const admin = createAdminClient();
  if (admin) {
    await admin.from("deletion_requests").insert({ email: normalized });
  }

  return NextResponse.json({
    ok: true,
    message: "Verification code sent. Check your email and enter the 6-digit code below.",
  });
}
