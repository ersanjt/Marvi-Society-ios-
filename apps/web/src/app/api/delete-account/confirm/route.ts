import { createClient } from "@supabase/supabase-js";
import { NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { isProduction, isSupabaseConfigured } from "@/config/env";
import { checkRateLimit } from "@/lib/security/rateLimit";

/** Step 2: verify OTP, purge app data, delete auth user. */
export async function POST(request: Request) {
  const rate = checkRateLimit(request, "delete-account-confirm", { limit: 6, windowMs: 60 * 60 * 1000 });
  if (!rate.ok) {
    return NextResponse.json(
      { error: "Too many verification attempts. Please try again later." },
      { status: 429, headers: { "Retry-After": String(rate.retryAfter) } }
    );
  }

  const { email, code } = await request.json();
  const normalizedEmail = String(email ?? "").trim().toLowerCase();
  const token = String(code ?? "").trim();

  if (!normalizedEmail || !token) {
    return NextResponse.json({ error: "Email and verification code required" }, { status: 400 });
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!isSupabaseConfigured() || !url || !anonKey || url.includes("YOUR_PROJECT")) {
    if (isProduction()) {
      return NextResponse.json(
        { error: "Account deletion is temporarily unavailable. Email support@marvisociety.com." },
        { status: 503 }
      );
    }
    return NextResponse.json({ error: "Server not configured" }, { status: 503 });
  }

  const supabase = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: verifyData, error: verifyError } = await supabase.auth.verifyOtp({
    email: normalizedEmail,
    token,
    type: "email",
  });

  if (verifyError || !verifyData.session || !verifyData.user) {
    return NextResponse.json(
      { error: verifyError?.message ?? "Invalid or expired verification code." },
      { status: 400 }
    );
  }

  const userId = verifyData.user.id;
  const userClient = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${verifyData.session.access_token}` } },
  });

  const { error: rpcError } = await userClient.rpc("delete_own_account");
  if (rpcError) {
    return NextResponse.json({ error: rpcError.message }, { status: 500 });
  }

  const admin = createAdminClient();
  if (!admin) {
    return NextResponse.json(
      { error: "Account data removed but auth deletion requires SUPABASE_SERVICE_ROLE_KEY on the server." },
      { status: 503 }
    );
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
  if (deleteError) {
    return NextResponse.json({ error: deleteError.message }, { status: 500 });
  }

  return NextResponse.json({
    ok: true,
    message: "Your Marvi Society account has been permanently deleted.",
  });
}
