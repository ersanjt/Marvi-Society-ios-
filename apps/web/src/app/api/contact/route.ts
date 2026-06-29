import { NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { isSupabaseConfigured } from "@/config/env";
import { queueSupportEmail } from "@/lib/email/notifySupport";
import { checkRateLimit } from "@/lib/security/rateLimit";

export async function POST(request: Request) {
  const rate = checkRateLimit(request, "contact", { limit: 5, windowMs: 60 * 60 * 1000 });
  if (!rate.ok) {
    return NextResponse.json(
      { error: "Too many messages. Please try again later." },
      { status: 429, headers: { "Retry-After": String(rate.retryAfter) } }
    );
  }

  const body = await request.json();
  const name = String(body.name ?? "").trim();
  const email = String(body.email ?? "").trim().toLowerCase();
  const subject = String(body.subject ?? "General support").trim();
  const message = String(body.message ?? "").trim();

  if (!name || !email || !message) {
    return NextResponse.json({ error: "Name, email, and message are required." }, { status: 400 });
  }

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return NextResponse.json({ error: "Invalid email address." }, { status: 400 });
  }

  if (!isSupabaseConfigured()) {
    return NextResponse.json(
      { error: "Support form is unavailable until Supabase is configured." },
      { status: 503 }
    );
  }

  const admin = createAdminClient();
  if (!admin) {
    return NextResponse.json(
      { error: "Support form is temporarily unavailable. Email support@marvisociety.com directly." },
      { status: 503 }
    );
  }

  const { error: insertError } = await admin.from("contact_messages").insert({
    name,
    email,
    subject,
    message,
    source: "web",
  });

  if (insertError) {
    return NextResponse.json({ error: insertError.message }, { status: 500 });
  }

  const queued = await queueSupportEmail("contact_form", {
    name,
    email,
    subject,
    message,
    site_url: "https://marvisociety.com",
  });

  if (!queued.ok) {
    return NextResponse.json({
      ok: true,
      warning: "Message saved but email notification could not be queued. Our team will follow up.",
    });
  }

  return NextResponse.json({
    ok: true,
    message: "Message sent. We typically reply within 1–2 business days.",
  });
}
