import { NextResponse } from "next/server";

import assetLinks from "../../../../public/.well-known/assetlinks.json";

export function GET() {
  return NextResponse.json(assetLinks, {
    headers: {
      "Cache-Control": "public, max-age=3600",
    },
  });
}
