import { createClient } from "@/lib/supabase/server";
import { VenueReviewQueue } from "@/components/portal/VenueReviewQueue";

export const metadata = { title: "Venue review queue" };

export default async function PortalReviewsPage() {
  const supabase = await createClient();
  const { data } = await supabase.rpc("fetch_venue_review_queue");
  const items = (data ?? []) as Array<Record<string, unknown>>;

  return (
    <div className="mx-auto max-w-4xl px-4 py-12 md:px-6">
      <h1 className="font-serif text-3xl font-bold text-ink">Review queue</h1>
      <p className="mt-1 text-sm text-muted">Check in, proof, and post-visit ratings for your venue.</p>
      <div className="mt-8">
        <VenueReviewQueue
          initialItems={items.map((item) => ({
            booking_id: String(item.booking_id),
            creator_name: String(item.creator_name ?? "Creator"),
            instagram_handle: String(item.instagram_handle ?? ""),
            venue_name: String(item.venue_name ?? "Venue"),
            offer_title: String(item.offer_title ?? "Campaign"),
            stage: String(item.stage ?? ""),
            proof_status: String(item.proof_status ?? ""),
          }))}
        />
      </div>
    </div>
  );
}
