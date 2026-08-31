import Stripe from "stripe";
import { isStripeConfigured } from "@/config/env";

export function getStripe(): Stripe | null {
  if (!isStripeConfigured()) return null;
  const key = process.env.STRIPE_SECRET_KEY!.trim();
  return new Stripe(key);
}
