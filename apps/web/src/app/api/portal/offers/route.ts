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
  const { title, model, slots, valueLabel, deliverables } = body;

  if (!title || !slots || !Array.isArray(deliverables) || deliverables.length === 0) {
    return NextResponse.json({ error: "Missing required fields" }, { status: 400 });
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({
      ok: true,
      mode: "preview",
      message: "Campaign saved in preview mode (sign in with Supabase to persist).",
    });
  }

  const { data: venues } = await supabase
    .from("venue_profiles")
    .select("id, venue_name, lat, lng, category")
    .eq("owner_user_id", user.id)
    .limit(1);

  const venue = venues?.[0];
  if (!venue) {
    return NextResponse.json(
      { error: "No venue profile linked to this account. Contact support to onboard." },
      { status: 400 }
    );
  }

  const collaborationModel = MODEL_MAP[String(model).toLowerCase()] ?? "invitation";

  const { data: offer, error: offerError } = await supabase
    .from("offers")
    .insert({
      venue_id: venue.id,
      title,
      category: venue.category ?? "dining",
      model: collaborationModel,
      date_label: "TBD",
      time_label: "Flexible",
      value_label: valueLabel ?? "Complimentary experience",
      capacity: slots,
      remaining_slots: slots,
      description: `${title} — submitted via brand portal.`,
      deliverables,
      requirements: ["Approved creator membership"],
      host_note: "Submitted for admin review.",
      status: "review",
      lat: venue.lat,
      lng: venue.lng,
    })
    .select("id, title")
    .single();

  if (offerError) {
    return NextResponse.json({ error: offerError.message }, { status: 500 });
  }

  await supabase.from("admin_tasks").insert({
    type: "campaign_review",
    subject_id: offer.id,
    title: offer.title,
    subtitle: `${venue.venue_name} requested ${slots} creator slots.`,
    priority: "High",
    status: "open",
  });

  return NextResponse.json({
    ok: true,
    message: "Campaign submitted. Admin will review before it goes live.",
  });
}
