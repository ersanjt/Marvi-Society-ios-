import { createClient } from "@supabase/supabase-js";
import { NextResponse } from "next/server";
import { isProduction, isSupabaseConfigured } from "@/config/env";
import { queueSupportEmail } from "@/lib/email/notifySupport";

export async function POST(request: Request) {
  const body = await request.json();
  const { firstName, lastName, company, email, website, message } = body;

  if (!firstName || !lastName || !company || !email) {
    return NextResponse.json({ error: "Missing required fields" }, { status: 400 });
  }

  if (!isSupabaseConfigured()) {
    if (isProduction()) {
      return NextResponse.json({ error: "Demo form unavailable — Supabase not configured." }, { status: 503 });
    }
    return NextResponse.json({
      ok: true,
      mode: "preview",
      message: "Demo request received (configure Supabase to persist).",
    });
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY ?? process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!url || !key) {
    return NextResponse.json({ error: "Server configuration error." }, { status: 503 });
  }

  const supabase = createClient(url, key);
  const { error } = await supabase.from("demo_requests").insert({
    first_name: firstName,
    last_name: lastName,
    company,
    email,
    website: website ?? null,
    message: message ?? null,
    source: "web",
  });

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  const fullName = `${firstName} ${lastName}`.trim();
  await queueSupportEmail("demo_request", {
    name: fullName,
    company: String(company),
    email: String(email).toLowerCase(),
    website: String(website ?? "—"),
    message: String(message ?? ""),
    site_url: "https://marvisociety.com",
  });

  return NextResponse.json({
    ok: true,
    message: "Demo request submitted. We'll contact you within 1–2 business days.",
  });
}
