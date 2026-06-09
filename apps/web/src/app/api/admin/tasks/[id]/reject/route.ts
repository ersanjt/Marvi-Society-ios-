import { createClient } from "@supabase/supabase-js";
import { NextResponse } from "next/server";

export async function POST(_: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY ?? process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (url && key && !url.includes("YOUR_PROJECT")) {
    const supabase = createClient(url, key);
    await supabase.from("admin_tasks").update({ status: "rejected", resolved_at: new Date().toISOString() }).eq("id", id);
  }

  return NextResponse.redirect(new URL("/admin", process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000"));
}
