import { createClient } from "@/lib/supabase/server";
import { CreatorSwipeDeck } from "@/components/portal/CreatorSwipeDeck";

export const metadata = { title: "Creator matching" };

export default async function PortalCreatorsPage({
  searchParams,
}: {
  searchParams: Promise<{ offerId?: string }>;
}) {
  const params = await searchParams;
  const supabase = await createClient();
  const { data } = await supabase.rpc("fetch_swipe_candidates", {
    p_offer_id: params.offerId ?? null,
  });
  const candidates = (data ?? []) as Array<Record<string, unknown>>;

  return (
    <div className="mx-auto max-w-3xl px-4 py-12 md:px-6">
      <h1 className="font-serif text-3xl font-bold text-ink">Creator matching</h1>
      <p className="mt-1 text-sm text-muted">Swipe through approved creators for your campaigns.</p>
      <div className="mt-8">
        <CreatorSwipeDeck
          offerId={params.offerId}
          initialCandidates={candidates.map((item) => ({
            creator_id: String(item.creator_id),
            full_name: String(item.full_name ?? "Creator"),
            instagram_handle: String(item.instagram_handle ?? ""),
            city: String(item.city ?? ""),
            score: Number(item.score ?? 0),
            audience_count: Number(item.audience_count ?? 0),
          }))}
        />
      </div>
    </div>
  );
}
