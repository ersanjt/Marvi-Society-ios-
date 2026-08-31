import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { getStripe } from "@/lib/stripe/server";
import { BILLING } from "@/lib/billing/plans";
import { getPublicSiteUrl, isStripeConfigured } from "@/config/env";

async function resolveVenueId(
  supabase: Awaited<ReturnType<typeof createClient>>,
  userId: string,
  requested?: string | null
) {
  const { data: venues } = await supabase.rpc("fetch_my_venues");
  const list = Array.isArray(venues) ? venues : [];
  if (requested && list.some((v: { id: string }) => v.id === requested)) {
    return requested;
  }
  const active = list.find((v: { is_active: boolean }) => v.is_active) ?? list[0];
  if (active?.id) return String(active.id);

  const { data: owned } = await supabase
    .from("venue_profiles")
    .select("id")
    .eq("owner_user_id", userId)
    .order("created_at", { ascending: true })
    .limit(1);
  return owned?.[0]?.id ?? null;
}

export async function POST(request: Request) {
  if (!isStripeConfigured()) {
    return NextResponse.json(
      { error: "Billing is not configured yet. Request a demo and we will activate Partner billing." },
      { status: 503 }
    );
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

  const body = await request.json().catch(() => ({}));
  const kind = String(body.kind ?? "partner");
  const offerId = typeof body.offerId === "string" ? body.offerId : null;
  const venueId = await resolveVenueId(supabase, user.id, body.venueId);
  if (!venueId) {
    return NextResponse.json({ error: "No venue profile on this account." }, { status: 400 });
  }

  const origin = getPublicSiteUrl();
  const partnerPrice = process.env.STRIPE_PARTNER_PRICE_ID?.trim();
  const boostPrice = process.env.STRIPE_BOOST_PRICE_ID?.trim();

  if (kind === "boost") {
    if (!offerId) {
      return NextResponse.json({ error: "Select a live campaign to boost." }, { status: 400 });
    }
    const admin = createAdminClient();
    const client = admin ?? supabase;
    const { data: offer } = await client
      .from("offers")
      .select("id, status, venue_id, deleted_at")
      .eq("id", offerId)
      .maybeSingle();
    if (!offer || offer.venue_id !== venueId || offer.status !== "live" || offer.deleted_at) {
      return NextResponse.json({ error: "Boost is only available for your live campaigns." }, { status: 400 });
    }

    const session = await stripe.checkout.sessions.create({
      mode: "payment",
      customer_email: user.email ?? undefined,
      client_reference_id: user.id,
      metadata: {
        kind: "boost",
        venue_id: venueId,
        offer_id: offerId,
        user_id: user.id,
      },
      line_items: boostPrice
        ? [{ price: boostPrice, quantity: 1 }]
        : [
            {
              quantity: 1,
              price_data: {
                currency: BILLING.currency,
                unit_amount: BILLING.boost.amountCents,
                product_data: {
                  name: `Marvi Featured Boost (${BILLING.boost.days} days)`,
                  description: "Pin this campaign in Discover featured for creators.",
                },
              },
            },
          ],
      success_url: `${origin}/portal/billing?boost=success&session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${origin}/portal/billing?boost=cancel`,
    });

    return NextResponse.json({ url: session.url });
  }

  const session = await stripe.checkout.sessions.create({
    mode: "subscription",
    customer_email: user.email ?? undefined,
    client_reference_id: user.id,
    metadata: {
      kind: "partner",
      venue_id: venueId,
      user_id: user.id,
    },
    subscription_data: {
      metadata: {
        venue_id: venueId,
        user_id: user.id,
      },
    },
    line_items: partnerPrice
      ? [{ price: partnerPrice, quantity: 1 }]
      : [
          {
            quantity: 1,
            price_data: {
              currency: BILLING.currency,
              unit_amount: BILLING.partner.amountCents,
              recurring: { interval: "month" },
              product_data: {
                name: "Marvi Partner",
                description: "Unlimited live campaigns for one venue.",
              },
            },
          },
        ],
    success_url: `${origin}/portal/billing?plan=success&session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${origin}/portal/billing?plan=cancel`,
  });

  return NextResponse.json({ url: session.url });
}
