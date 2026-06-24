import Image from "next/image";

export const APP_SCREENSHOTS = [
  {
    id: "discover",
    src: "/screenshots/iphone/marvi-01-kesfet.png",
    label: "Keşfet",
    labelEn: "Explore",
    caption: "Browse curated Istanbul invitations by category, map, and collaboration model.",
    captionTr: "Kategori, harita ve iş birliği modeline göre İstanbul davetlerini keşfedin.",
  },
  {
    id: "profile",
    src: "/screenshots/iphone/marvi-02-profil-creator.png",
    label: "Profil",
    labelEn: "Profile",
    caption: "Creator health score, workspace switcher, and membership status.",
    captionTr: "Creator sağlık skoru, çalışma alanı ve üyelik durumu.",
  },
  {
    id: "events",
    src: "/screenshots/iphone/marvi-03-etkinliklerim.png",
    label: "Etkinliklerim",
    labelEn: "My Events",
    caption: "Confirmed bookings, check-in codes, and proof submission workflow.",
    captionTr: "Onaylı rezervasyonlar, check-in kodları ve kanıt gönderimi.",
  },
  {
    id: "social",
    src: "/screenshots/iphone/marvi-04-sosyal-hesaplar.png",
    label: "Sosyal Hesaplar",
    labelEn: "Social accounts",
    caption: "Connect Instagram and TikTok for audience verification.",
    captionTr: "Kitle doğrulaması için Instagram ve TikTok bağlantısı.",
  },
  {
    id: "legal",
    src: "/screenshots/iphone/marvi-05-yasal-hesap.png",
    label: "Yasal & Hesap",
    labelEn: "Legal & account",
    caption: "Privacy, terms, community guidelines, and account deletion.",
    captionTr: "Gizlilik, şartlar, topluluk kuralları ve hesap silme.",
  },
] as const;

type PhoneFrameProps = {
  src: string;
  alt: string;
  priority?: boolean;
  className?: string;
};

/** iPhone-style frame matching App Store screenshot proportions */
export function PhoneFrame({ src, alt, priority = false, className = "" }: PhoneFrameProps) {
  return (
    <div
      className={`relative mx-auto w-full max-w-[280px] rounded-[2.25rem] border border-white/10 bg-panel p-2 shadow-rose ${className}`}
    >
      <div className="absolute left-1/2 top-3 z-10 h-5 w-24 -translate-x-1/2 rounded-full bg-surface" aria-hidden />
      <div className="relative overflow-hidden rounded-[1.75rem] bg-surface">
        <Image
          src={src}
          alt={alt}
          width={1284}
          height={2778}
          priority={priority}
          className="h-auto w-full"
          sizes="(max-width: 768px) 70vw, 280px"
        />
      </div>
    </div>
  );
}
