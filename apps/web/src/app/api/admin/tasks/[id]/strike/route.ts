import { NextResponse } from "next/server";
import { requireAdmin } from "@/lib/auth/admin";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";

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

  const rpcBody = {
    p_booking_id: bookingId,
    p_reason: reason,
    p_severity: "medium",
  };

  const admin = createAdminClient();
  if (admin) {
    const { error } = await admin.rpc("issue_strike_for_booking", rpcBody);
    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }
  } else {
    const supabase = await createClient();
    const { error } = await supabase.rpc("issue_strike_for_booking", rpcBody);
    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }
  }

  void taskId;
  return NextResponse.redirect(new URL("/admin", process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000"));
}
