import { requireAdmin } from "@/lib/auth/admin";
import { createClient } from "@/lib/supabase/server";
import { NextResponse } from "next/server";

type Body = {
  status?: "draft" | "review" | "live" | "completed";
  reason?: string;
  action?: "delete" | "restore" | "status";
};

export async function POST(
  request: Request,
  context: { params: Promise<{ id: string }> }
) {
  const gate = await requireAdmin();
  if (!gate.ok) return NextResponse.json({ error: gate.error }, { status: gate.status });

  const { id } = await context.params;
  const body = (await request.json()) as Body;
  const supabase = await createClient();
  const action = body.action ?? "status";

  if (action === "delete") {
    const { error } = await supabase.rpc("admin_soft_delete_offer", {
      p_offer_id: id,
      p_reason: body.reason ?? "Deleted by admin",
    });
    if (error) return NextResponse.json({ error: error.message }, { status: 400 });
    return NextResponse.json({ ok: true, message: "Campaign deleted" });
  }

  if (action === "restore") {
    const { error } = await supabase.rpc("admin_restore_offer", { p_offer_id: id });
    if (error) return NextResponse.json({ error: error.message }, { status: 400 });
    return NextResponse.json({ ok: true, message: "Campaign restored" });
  }

  if (!body.status) {
    return NextResponse.json({ error: "status required" }, { status: 400 });
  }

  const { error } = await supabase.rpc("admin_set_offer_status", {
    p_offer_id: id,
    p_status: body.status,
    p_reason: body.reason ?? null,
  });
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });
  return NextResponse.json({ ok: true, message: `Status → ${body.status}` });
}
