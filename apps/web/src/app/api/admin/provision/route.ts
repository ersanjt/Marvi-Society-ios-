import { NextResponse } from "next/server";
import { requireAdmin } from "@/lib/auth/admin";

export async function POST(request: Request) {
  const auth = await requireAdmin();
  if (!auth.ok) {
    return NextResponse.json({ error: auth.error }, { status: auth.status });
  }

  const body = await request.json();
  const url = `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/admin-provision-user`;
  const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  const serviceRole = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !anon) {
    return NextResponse.json({ error: "Supabase not configured" }, { status: 500 });
  }

  const supabase = await (await import("@/lib/supabase/server")).createClient();
  const { data: session } = await supabase.auth.getSession();
  const accessToken = session.session?.access_token;

  if (!accessToken) {
    return NextResponse.json({ error: "Session expired" }, { status: 401 });
  }

  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: anon,
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify(body),
  });

  const json = await response.json();
  if (!response.ok) {
    return NextResponse.json({ error: json.error ?? "Provision failed" }, { status: response.status });
  }

    return NextResponse.json({
    message: "User created successfully. Credentials were delivered via the configured channel.",
    user_id: json.user_id,
  });
}
