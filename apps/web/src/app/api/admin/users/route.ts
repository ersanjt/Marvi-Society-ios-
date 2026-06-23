import { NextResponse } from "next/server";
import { adminRpc } from "@/lib/admin/rpc";

export async function GET() {
  const result = await adminRpc((client) =>
    client.rpc("admin_list_users", { p_search: null, p_status: null, p_limit: 100 })
  );

  if (!result.ok) {
    return NextResponse.json({ error: result.error }, { status: result.status });
  }

  return NextResponse.json({ users: result.data });
}
