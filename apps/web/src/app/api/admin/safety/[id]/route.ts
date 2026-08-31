import { NextResponse } from "next/server";
import { requireAdmin } from "@/lib/auth/admin";
import { createClient } from "@/lib/supabase/server";

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const auth = await requireAdmin();
  if (!auth.ok) {
    return NextResponse.json({ error: auth.error }, { status: auth.status });
  }

  const { id } = await params;
  const body = await request.json().catch(() => ({}));
  const status = String(body.status ?? "");
  const notes = typeof body.notes === "string" ? body.notes : null;
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_set_safety_report_status", {
    p_id: id,
    p_status: status,
    p_notes: notes,
  });
  if (error) {
    return NextResponse.json({ error: error.message }, { status: 400 });
  }
  return NextResponse.json({ ok: true });
}
