import { createClient } from "@/lib/supabase/server";
import { NextResponse } from "next/server";

const MODEL_MAP: Record<string, string> = {
  invitation: "invitation",
  event: "event",
  gift: "gift",
  instant: "instant",
};

export async function POST(request: Request) {
  const body = await request.json();
  const { title, model, slots, valueLabel, deliverables, dateLabel } = body;

  if (!title || !slots || !Array.isArray(deliverables) || deliverables.length === 0) {
    return NextResponse.json({ error: "Missing required fields" }, { status: 400 });
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const collaborationModel = MODEL_MAP[String(model).toLowerCase()] ?? "invitation";

  let activeVenue: { id: string; category?: string } | null = null;
  const { data: venues, error: venuesError } = await supabase.rpc("fetch_my_venues");

  if (!venuesError && venues?.length) {
    activeVenue =
      venues.find((v: { is_active: boolean }) => v.is_active) ?? venues[0] ?? null;
  }

  if (!activeVenue) {
    const { data: ownedVenues } = await supabase
      .from("venue_profiles")
      .select("id, category")
      .eq("owner_user_id", user.id)
      .order("created_at", { ascending: true })
      .limit(1);

    activeVenue = ownedVenues?.[0] ?? null;
  }

  if (!activeVenue) {
    return NextResponse.json(
      { error: "No venue profile linked to this account. Add a location in the portal." },
      { status: 400 }
    );
  }

  const { data: offerID, error: rpcError } = await supabase.rpc("submit_campaign_for_review", {
    p_title: title,
    p_category: activeVenue.category ?? "dining",
    p_model: collaborationModel,
    p_date_label: dateLabel ?? "TBD",
    p_value_label: valueLabel ?? "Complimentary experience",
    p_slots: slots,
    p_deliverables: deliverables,
    ...(venuesError ? {} : { p_venue_id: activeVenue.id }),
  });

  if (rpcError) {
    return NextResponse.json({ error: rpcError.message }, { status: 500 });
  }

  return NextResponse.json({
    ok: true,
    offerId: offerID,
    message: "Campaign submitted. Admin will review before it goes live.",
  });
}
