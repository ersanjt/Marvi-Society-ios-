import { createClient } from "@supabase/supabase-js";
import { NextResponse } from "next/server";

export async function POST(request: Request) {
  const body = await request.json();
  const { firstName, lastName, company, email, website, message } = body;

  if (!firstName || !lastName || !company || !email) {
    return NextResponse.json({ error: "Missing required fields" }, { status: 400 });
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY ?? process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!url || !key || url.includes("YOUR_PROJECT")) {
    return NextResponse.json({
      ok: true,
      mode: "preview",
      message: "Demo request received (configure Supabase to persist).",
    });
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

  return NextResponse.json({ ok: true });
}
