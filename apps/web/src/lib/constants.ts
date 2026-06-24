export { SITE, NAV_LINKS, ADMIN_NAV, PORTAL_NAV } from "@/config/site";
export { MARVI_URLS, REFERRAL_CODES } from "@marvi/shared";

export const COLLABORATION_MODELS = [
  {
    id: "invitation",
    title: "Invitation",
    titleTr: "Davet",
    description:
      "Schedule creator visits at your preferred dates. Ideal for restaurants, salons, and content-guaranteed experiences.",
    descriptionTr:
      "Tercih ettiğiniz tarihlerde üretici ziyaretleri planlayın. Restoranlar, salonlar ve içerik garantili deneyimler için ideal.",
    iconId: "invitation" as const,
  },
  {
    id: "event",
    title: "Event",
    titleTr: "Etkinlik",
    description:
      "Host group experiences with multiple creators. Manage RSVPs and measure reach from one place.",
    descriptionTr:
      "Birden fazla üreticiyle grup deneyimleri düzenleyin. RSVP'leri yönetin ve erişimi tek yerden ölçün.",
    iconId: "event" as const,
  },
  {
    id: "gift",
    title: "Gift",
    titleTr: "Hediye",
    description:
      "Ship products to creators and receive guaranteed authentic content with tracked delivery.",
    descriptionTr:
      "Ürünleri üreticilere gönderin ve takip edilen teslimatla garantili özgün içerik alın.",
    iconId: "gift" as const,
  },
  {
    id: "instant",
    title: "Instant",
    titleTr: "Anlık",
    description:
      "Walk-in collaborations nearby. Creators open the map, accept, visit, and post — no waiting.",
    descriptionTr:
      "Yakındaki walk-in iş birlikleri. Üreticiler haritayı açar, kabul eder, ziyaret eder ve paylaşır — bekleme yok.",
    iconId: "instant" as const,
  },
] as const;

export const FAQ_ITEMS = [
  {
    category: "Membership",
    questions: [
      {
        q: "What do I need to join as a creator?",
        a: "An independent creator account, original content, and typically 5,000+ followers. Applications are reviewed by our team.",
      },
      {
        q: "Is Marvi Society free for creators?",
        a: "Yes. Collaborations are barter-based — experiences in exchange for structured social content.",
      },
    ],
  },
  {
    category: "Collaborations",
    questions: [
      {
        q: "What types of offers are available?",
        a: "Invitation, Event, Gift, and Instant models across dining, nightlife, wellness, beauty, fitness, and retail.",
      },
      {
        q: "What content must I deliver?",
        a: "Each offer lists deliverables — typically stories, Reels, or posts with venue tags within the proof window.",
      },
    ],
  },
  {
    category: "Venues",
    questions: [
      {
        q: "How do venues join?",
        a: "Request a demo. Our team onboards your venue, helps craft campaigns, and routes creator matching through admin review.",
      },
      {
        q: "Do venues pay creators directly?",
        a: "No. Marvi Society operates on complimentary experiences in exchange for guaranteed content delivery.",
      },
    ],
  },
] as const;
