import { createClient } from "@/lib/supabase/server";
import { VenueReviewQueue } from "@/components/portal/VenueReviewQueue";
import { MarviScreen, PageHeader } from "@/components/design/MarviUI";
import { getI18n } from "@/lib/i18n/locale";
import { getPortalAdminDict } from "@/lib/i18n/portal-admin";

export async function generateMetadata() {
  const { locale } = await getI18n();
  return { title: getPortalAdminDict(locale).portal.reviews.metaTitle };
}

export default async function PortalReviewsPage() {
  const { locale } = await getI18n();
  const dict = getPortalAdminDict(locale);
  const r = dict.portal.reviews;
  const c = dict.common;

  const supabase = await createClient();
  const { data } = await supabase.rpc("fetch_venue_review_queue");
  const items = (data ?? []) as Array<Record<string, unknown>>;

  return (
    <MarviScreen>
      <div className="mx-auto max-w-4xl px-4 py-10 md:px-6 md:py-12">
        <PageHeader eyebrow={r.eyebrow} title={r.title} subtitle={r.subtitle} />
        <div className="mt-8">
          <VenueReviewQueue
            dict={dict}
            locale={locale}
            initialItems={items.map((item) => ({
              booking_id: String(item.booking_id),
              creator_name: String(item.creator_name ?? c.creator),
              instagram_handle: String(item.instagram_handle ?? ""),
              venue_name: String(item.venue_name ?? c.venue),
              offer_title: String(item.offer_title ?? "Campaign"),
              stage: String(item.stage ?? ""),
              proof_status: String(item.proof_status ?? ""),
            }))}
          />
        </div>
      </div>
    </MarviScreen>
  );
}
