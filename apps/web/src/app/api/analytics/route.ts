import { createClient } from "@/lib/supabase/server";
import { NextResponse } from "next/server";
import { checkRateLimit } from "@/lib/security/rateLimit";

const MAX_PROPERTIES_BYTES = 4096;

export async function POST(request: Request) {
  const rate = checkRateLimit(request, "analytics", { limit: 120, windowMs: 60 * 1000 });
  if (!rate.ok) {
    return NextResponse.json(
      { error: "Too many events." },
      { status: 429, headers: { "Retry-After": String(rate.retryAfter) } }
    );
  }

  const body = await request.json();
  const name = String(body.name ?? "").trim();
  const properties = body.properties ?? {};

  if (!/^[a-zA-Z0-9_.:-]{1,80}$/.test(name)) {
    return NextResponse.json({ error: "Missing event name" }, { status: 400 });
  }

  if (
    typeof properties !== "object" ||
    properties === null ||
    Array.isArray(properties) ||
    JSON.stringify(properties).length > MAX_PROPERTIES_BYTES
  ) {
    return NextResponse.json({ error: "Invalid event properties" }, { status: 400 });
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ ok: true, mode: "anonymous" });
  }

  const { error } = await supabase.rpc("track_analytics_event", {
    p_name: name,
    p_properties: properties,
  });

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true });
}
