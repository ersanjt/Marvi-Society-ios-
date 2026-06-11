import { createClient } from "@/lib/supabase/server";
import { NextResponse } from "next/server";

export async function POST(request: Request) {
  const body = await request.json();
  const name = String(body.name ?? "").trim();
  const properties = body.properties ?? {};

  if (!name) {
    return NextResponse.json({ error: "Missing event name" }, { status: 400 });
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
