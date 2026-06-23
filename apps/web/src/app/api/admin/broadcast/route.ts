import { NextResponse } from "next/server";
import { adminRpc } from "@/lib/admin/rpc";

export async function POST(request: Request) {
  const { lat, lng, radius_km, title, body } = await request.json();

  const result = await adminRpc<number>((client) =>
    client.rpc("admin_notify_users_in_radius", {
      p_lat: lat,
      p_lng: lng,
      p_radius_km: radius_km,
      p_title: title,
      p_body: body,
    })
  );

  if (!result.ok) {
    return NextResponse.json({ error: result.error }, { status: result.status });
  }

  const count = result.data ?? 0;
  return NextResponse.json({
    message:
      count === 0
        ? "No approved users with location in this radius."
        : `Sent to ${count} user(s) within ${radius_km} km.`,
  });
}
