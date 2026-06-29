import { NextResponse } from "next/server";
import { requireAdmin } from "@/lib/auth/admin";
import { createClient } from "@/lib/supabase/server";

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const auth = await requireAdmin();
  if (!auth.ok) {
    return NextResponse.json({ error: auth.error }, { status: auth.status });
  }

  const { id: taskId } = await params;
  const form = await request.formData();
  const bookingId = String(form.get("booking_id") ?? "");
  const reason = String(form.get("reason") ?? "Proof not delivered per campaign terms");

  if (!bookingId) {
    return NextResponse.json({ error: "booking_id required" }, { status: 400 });
  }

  // Use the admin's session so issue_strike_for_booking's is_admin() check passes.
  const supabase = await createClient();
  const { error } = await supabase.rpc("issue_strike_for_booking", {
    p_booking_id: bookingId,
    p_reason: reason,
    p_severity: "medium",
  });
  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  void taskId;
  return NextResponse.redirect(new URL("/admin", new URL(request.url).origin));
}
