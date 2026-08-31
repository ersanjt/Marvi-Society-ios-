import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { checkRateLimit } from "@/lib/security/rateLimit";
import { isSupabaseConfigured } from "@/config/env";

export async function POST(request: Request) {
  const rate = checkRateLimit(request, "safety", { limit: 8, windowMs: 60 * 60 * 1000 });
  if (!rate.ok) {
    return NextResponse.json(
      { error: "Too many reports. Try again later." },
      { status: 429, headers: { "Retry-After": String(rate.retryAfter) } }
    );
  }

  const body = await request.json().catch(() => ({}));
  const reportBody = String(body.body ?? "").trim();
  const category = String(body.category ?? "safety").trim() || "safety";
  const email = String(body.email ?? "").trim().toLowerCase();
  if (reportBody.length < 8) {
    return NextResponse.json({ error: "Please describe the issue." }, { status: 400 });
  }

  if (isSupabaseConfigured()) {
    try {
      const supabase = await createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();

      if (user) {
        const { error } = await supabase.rpc("submit_safety_report", {
          p_body: reportBody,
          p_category: category,
        });
        if (error) {
          return NextResponse.json({ error: error.message }, { status: 400 });
        }
        return NextResponse.json({ ok: true });
      }
    } catch {
      // Fall through to service-role insert when the session client is unavailable.
    }
  }

  const admin = createAdminClient();
  if (!admin) {
    return NextResponse.json({ error: "Reporting is temporarily unavailable." }, { status: 503 });
  }

  const { error } = await admin.from("safety_reports").insert({
    reporter_email: email || null,
    category,
    body: reportBody.slice(0, 4000),
    status: "open",
  });
  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
  return NextResponse.json({ ok: true });
}
