import { NextResponse } from "next/server";
import { adminRpc } from "@/lib/admin/rpc";

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const { subject, body } = await request.json();

  const result = await adminRpc((client) =>
    client.rpc("admin_send_email", { p_user_id: id, p_subject: subject, p_body: body })
  );

  if (!result.ok) {
    return NextResponse.json({ error: result.error }, { status: result.status });
  }

  return NextResponse.json({ message: "Email queued" });
}
