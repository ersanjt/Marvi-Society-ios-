import { createClient } from "@/lib/supabase/server";
import { NextResponse } from "next/server";

export async function POST(request: Request) {
  const body = await request.json();
  const { action, creatorId, offerId } = body;

  if (!creatorId || !["shortlist", "pass"].includes(action)) {
    return NextResponse.json({ error: "Invalid request" }, { status: 400 });
  }

  const supabase = await createClient();
  const rpc = action === "shortlist" ? "shortlist_creator" : "pass_creator";
  const { error } = await supabase.rpc(rpc, {
    p_creator_id: creatorId,
    p_offer_id: offerId ?? null,
  });

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true });
}
