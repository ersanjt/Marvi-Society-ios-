import { NextResponse } from "next/server";
import { adminRpc } from "@/lib/admin/rpc";

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const { status } = await request.json();

  const result = await adminRpc((client) =>
    client.rpc("admin_set_membership_status", { p_user_id: id, p_status: status })
  );

  if (!result.ok) {
    return NextResponse.json({ error: result.error }, { status: result.status });
  }

  return NextResponse.json({ message: `Status updated to ${status}` });
}
