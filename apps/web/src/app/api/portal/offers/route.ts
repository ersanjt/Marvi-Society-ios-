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
    return NextResponse.json({
      ok: true,
      mode: "preview",
      message: "Campaign saved in preview mode (sign in with Supabase to persist).",
    });
  }

  const collaborationModel = MODEL_MAP[String(model).toLowerCase()] ?? "invitation";

  const { data: venues } = await supabase
    .from("venue_profiles")
    .select("id, category, status")
    .eq("owner_user_id", user.id)
    .limit(1);

  const venue = venues?.[0];
  if (!venue) {
    return NextResponse.json(
      { error: "No venue profile linked to this account. Contact support to onboard." },
      { status: 400 }
    );
  }

  const { data: offerID, error: rpcError } = await supabase.rpc("submit_campaign_for_review", {
    p_title: title,
    p_category: venue.category ?? "dining",
    p_model: collaborationModel,
    p_date_label: dateLabel ?? "TBD",
    p_value_label: valueLabel ?? "Complimentary experience",
    p_slots: slots,
    p_deliverables: deliverables,
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
