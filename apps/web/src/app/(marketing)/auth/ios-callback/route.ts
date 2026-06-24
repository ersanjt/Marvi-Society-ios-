import { NextRequest, NextResponse } from "next/server";

const IOS_DEEP_LINK = "marvisociety://auth/callback";

/** Instant server redirect for iOS OAuth — no React, no web portal session. */
export function GET(request: NextRequest) {
  const deepLink = new URL(IOS_DEEP_LINK);
  request.nextUrl.searchParams.forEach((value, key) => {
    deepLink.searchParams.set(key, value);
  });
  return NextResponse.redirect(deepLink.toString());
}
