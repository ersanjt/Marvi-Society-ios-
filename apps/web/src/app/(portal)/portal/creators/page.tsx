import { createClient } from "@/lib/supabase/server";
import { CreatorSwipeDeck } from "@/components/portal/CreatorSwipeDeck";
import { MarviScreen, PageHeader } from "@/components/design/MarviUI";
import { getI18n } from "@/lib/i18n/locale";
import { getPortalAdminDict } from "@/lib/i18n/portal-admin";

export async function generateMetadata() {
  const { locale } = await getI18n();
  return { title: getPortalAdminDict(locale).portal.creators.metaTitle };
}

export default async function PortalCreatorsPage({
  searchParams,
}: {
  searchParams: Promise<{ offerId?: string }>;
}) {
  const { locale } = await getI18n();
  const dict = getPortalAdminDict(locale);
  const c = dict.portal.creators;

  const params = await searchParams;
  const supabase = await createClient();
  const { data } = await supabase.rpc("fetch_swipe_candidates", {
    p_offer_id: params.offerId ?? null,
  });
  const candidates = (data ?? []) as Array<Record<string, unknown>>;

  return (
    <MarviScreen>
      <div className="mx-auto max-w-3xl px-4 py-10 md:px-6 md:py-12">
        <PageHeader eyebrow={c.eyebrow} title={c.title} subtitle={c.subtitle} />
        <div className="mt-8">
          <CreatorSwipeDeck
            dict={dict}
            offerId={params.offerId}
            initialCandidates={candidates.map((item) => ({
              creator_id: String(item.creator_id),
              full_name: String(item.full_name ?? dict.common.creator),
              instagram_handle: String(item.instagram_handle ?? ""),
              city: String(item.city ?? ""),
              score: Number(item.score ?? 0),
              audience_count: Number(item.audience_count ?? 0),
            }))}
          />
        </div>
      </div>
    </MarviScreen>
  );
}
