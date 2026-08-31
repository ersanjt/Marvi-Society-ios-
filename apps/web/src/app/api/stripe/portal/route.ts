import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { getStripe } from "@/lib/stripe/server";
import { getPublicSiteUrl, isStripeConfigured } from "@/config/env";

export async function POST() {
  if (!isStripeConfigured()) {
    return NextResponse.json({ error: "Billing is not configured yet." }, { status: 503 });
  }

  const stripe = getStripe();
  if (!stripe) {
    return NextResponse.json({ error: "Stripe is unavailable." }, { status: 503 });
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const { data: billing } = await supabase.rpc("venue_billing_status");
  const customerId =
    billing && typeof billing === "object" && "stripe_customer_id" in billing
      ? String((billing as { stripe_customer_id?: string }).stripe_customer_id ?? "")
      : "";

  if (!customerId) {
    return NextResponse.json(
      { error: "No Stripe customer yet. Start Partner checkout first." },
      { status: 400 }
    );
  }

  const session = await stripe.billingPortal.sessions.create({
    customer: customerId,
    return_url: `${getPublicSiteUrl()}/portal/billing`,
  });

  return NextResponse.json({ url: session.url });
}
