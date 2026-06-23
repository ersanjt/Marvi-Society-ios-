import { NextResponse } from "next/server";
import { adminRpc } from "@/lib/admin/rpc";

export async function POST(request: Request) {
  const { email, invite_code, max_uses } = await request.json();

  const result = await adminRpc((client) =>
    client.rpc("admin_send_invite", {
      p_email: email,
      p_invite_code: invite_code ?? null,
      p_max_uses: max_uses ?? 1,
    })
  );

  if (!result.ok) {
    return NextResponse.json({ error: result.error }, { status: result.status });
  }

  const payload = result.data as { invite_code?: string } | null;
  return NextResponse.json({
    message: `Invite sent${payload?.invite_code ? ` (${payload.invite_code})` : ""}`,
  });
}
