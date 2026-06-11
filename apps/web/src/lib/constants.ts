import { MARVI_URLS } from "@marvi/shared";

export const SITE = {
  name: "Marvi Society",
  tagline: "Istanbul's private creator × venue collaboration club",
  description:
    "Approved creators discover curated venue experiences. Venues receive structured social content. Operators curate quality and trust.",
  url: MARVI_URLS.site,
  email: "hello@marvisociety.com",
  supportEmail: "support@marvisociety.com",
  appStoreUrl: "#",
  playStoreUrl: "#",
} as const;

export { MARVI_URLS, REFERRAL_CODES } from "@marvi/shared";

export const NAV_LINKS = [
  { href: "/brands", label: "Brands" },
  { href: "/creators", label: "Creators" },
  { href: "/faq", label: "FAQ" },
  { href: "/demo", label: "Get demo" },
] as const;

export const COLLABORATION_MODELS = [
  {
    id: "invitation",
    title: "Invitation",
    description:
      "Schedule creator visits at your preferred dates. Ideal for restaurants, salons, and content-guaranteed experiences.",
    icon: "📅",
  },
  {
    id: "event",
    title: "Event",
    description:
      "Host group experiences with multiple creators. Manage RSVPs and measure reach from one place.",
    icon: "🎉",
  },
  {
    id: "gift",
    title: "Gift",
    description:
      "Ship products to creators and receive guaranteed authentic content with tracked delivery.",
    icon: "🎁",
  },
  {
    id: "instant",
    title: "Instant",
    description:
      "Walk-in collaborations nearby. Creators open the map, accept, visit, and post — no waiting.",
    icon: "⚡",
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
