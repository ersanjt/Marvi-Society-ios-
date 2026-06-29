import { NextResponse } from "next/server";
import { requireAdmin } from "@/lib/auth/admin";
import { createClient } from "@/lib/supabase/server";

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const auth = await requireAdmin();
  if (!auth.ok) {
    return NextResponse.json({ error: auth.error }, { status: auth.status });
  }

  const { id } = await params;
  // Use the admin's session so resolve_admin_task's auth.uid()/is_admin() checks pass.
  const supabase = await createClient();
  const { error } = await supabase.rpc("resolve_admin_task", {
    p_task_id: id,
    p_action: "approve",
  });
  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  return NextResponse.redirect(new URL("/admin", new URL(request.url).origin));
}
