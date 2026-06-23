import { NextResponse } from "next/server";
import { adminRpc } from "@/lib/admin/rpc";

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const { title, body } = await request.json();

  const result = await adminRpc((client) =>
    client.rpc("admin_send_notification", {
      p_user_id: id,
      p_title: title,
      p_body: body,
      p_type: "admin",
    })
  );

  if (!result.ok) {
    return NextResponse.json({ error: result.error }, { status: result.status });
  }

  return NextResponse.json({ message: "Notification and push queued" });
}
