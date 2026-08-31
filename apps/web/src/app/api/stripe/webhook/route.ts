import { NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { getStripe } from "@/lib/stripe/server";
import { BILLING } from "@/lib/billing/plans";
import { isStripeConfigured } from "@/config/env";

function unixToIso(seconds: unknown): string | null {
  return typeof seconds === "number" ? new Date(seconds * 1000).toISOString() : null;
}

function subscriptionPeriodEnd(sub: unknown): string | null {
  if (!sub || typeof sub !== "object") return null;
  const rec = sub as Record<string, unknown>;
  if (typeof rec.current_period_end === "number") {
    return unixToIso(rec.current_period_end);
  }
  const items = rec.items as { data?: Array<{ current_period_end?: unknown }> } | undefined;
  return unixToIso(items?.data?.[0]?.current_period_end);
}

export async function POST(request: Request) {
  if (!isStripeConfigured()) {
    return NextResponse.json({ error: "Stripe is not configured." }, { status: 503 });
  }

  const stripe = getStripe();
  const secret = process.env.STRIPE_WEBHOOK_SECRET?.trim();
  if (!stripe || !secret) {
    return NextResponse.json({ error: "Webhook secret missing." }, { status: 503 });
  }

  const signature = request.headers.get("stripe-signature");
  if (!signature) {
    return NextResponse.json({ error: "Missing signature." }, { status: 400 });
  }

  const raw = await request.text();
  let event;
  try {
    event = stripe.webhooks.constructEvent(raw, signature, secret);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Invalid payload";
    return NextResponse.json({ error: message }, { status: 400 });
  }

  const admin = createAdminClient();
  if (!admin) {
    return NextResponse.json({ error: "Database unavailable." }, { status: 503 });
  }

  if (event.type === "checkout.session.completed") {
    const session = event.data.object;
    const kind = session.metadata?.kind;
    const venueId = session.metadata?.venue_id;
    const offerId = session.metadata?.offer_id;

    if (kind === "boost" && offerId) {
      await admin.rpc("apply_paid_boost", {
        p_offer_id: offerId,
        p_session_id: session.id,
        p_days: BILLING.boost.days,
        p_amount_cents: BILLING.boost.amountCents,
        p_payment_intent: typeof session.payment_intent === "string" ? session.payment_intent : null,
      });
    }

    if (kind === "partner" && venueId) {
      const subscriptionId =
        typeof session.subscription === "string" ? session.subscription : null;
      let periodEnd: string | null = null;
      if (subscriptionId) {
        const sub = await stripe.subscriptions.retrieve(subscriptionId);
        periodEnd = subscriptionPeriodEnd(sub);
      }
      await admin.rpc("activate_partner_subscription", {
        p_venue_id: venueId,
        p_customer_id: typeof session.customer === "string" ? session.customer : "",
        p_subscription_id: subscriptionId ?? `checkout_${session.id}`,
        p_period_end: periodEnd,
        p_status: "active",
      });
    }
  }

  if (
    event.type === "customer.subscription.updated" ||
    event.type === "customer.subscription.deleted"
  ) {
    const sub = event.data.object;
    const venueId = sub.metadata?.venue_id;
    if (venueId) {
      const status =
        event.type === "customer.subscription.deleted"
          ? "canceled"
          : sub.status === "active" || sub.status === "trialing"
            ? "active"
            : sub.status === "past_due"
              ? "past_due"
              : "canceled";
      await admin.rpc("activate_partner_subscription", {
        p_venue_id: venueId,
        p_customer_id: typeof sub.customer === "string" ? sub.customer : "",
        p_subscription_id: sub.id,
        p_period_end: subscriptionPeriodEnd(sub),
        p_status: status,
      });
    }
  }

  return NextResponse.json({ received: true });
}
