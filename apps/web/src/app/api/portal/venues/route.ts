import { createClient } from "@/lib/supabase/server";
import { NextResponse } from "next/server";

export async function GET() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ venues: [] });
  }

  const { data, error } = await supabase.rpc("fetch_my_venues");

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  return NextResponse.json({ venues: data ?? [] });
}

export async function POST(request: Request) {
  const body = await request.json();
  const { venueName, area, category, address, contactName, contactPhone } = body;

  if (!venueName || !area || !category) {
    return NextResponse.json({ error: "Venue name, area, and category are required" }, { status: 400 });
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const { data: venueID, error } = await supabase.rpc("register_venue_location", {
    p_venue_name: String(venueName),
    p_area: String(area),
    p_category: String(category),
    p_address: address ?? "",
    p_contact_name: contactName ?? "",
    p_contact_phone: contactPhone ?? "",
  });

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true, venueId: venueID });
}

export async function PATCH(request: Request) {
  const body = await request.json();
  const { venueId } = body;

  if (!venueId) {
    return NextResponse.json({ error: "venueId is required" }, { status: 400 });
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const { error } = await supabase.rpc("set_active_venue", { p_venue_id: venueId });

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true });
}
