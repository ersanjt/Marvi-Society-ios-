import { createClient } from "@/lib/supabase/server";
import { NextResponse } from "next/server";

export async function POST(request: Request) {
  const body = await request.json();
  const { bookingId, punctuality, presentation, comment } = body;

  if (!bookingId) {
    return NextResponse.json({ error: "Missing bookingId" }, { status: 400 });
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc("submit_venue_review", {
    p_booking_id: bookingId,
    p_punctuality: Number(punctuality ?? 5),
    p_presentation: Number(presentation ?? 5),
    p_comment: String(comment ?? ""),
  });

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true });
}
