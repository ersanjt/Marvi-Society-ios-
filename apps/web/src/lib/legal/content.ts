import type { LegalDocument, LegalLocale } from "./types";

const privacyEn: LegalDocument = {
  title: "Privacy Policy",
  subtitle: "Last updated: 10 June 2026",
  intro:
    "Marvi Society (“Marvi”, “we”, “us”) operates a private, invitation-only marketplace that connects approved creators with verified venue partners in Istanbul and other cities. This Privacy Policy explains what personal data we collect, why we collect it, how long we keep it, and your rights.",
  sections: [
    {
      id: "controller",
      title: "Data controller",
      paragraphs: [
        "Marvi Society is the data controller for personal data processed through the Marvi Society iOS and Android apps, website (marvisociety.com), and related services.",
        "Contact: support@marvisociety.com",
      ],
    },
    {
      id: "data-collected",
      title: "Personal data we collect",
      bullets: [
        "Account data: email address, name, Apple or Google identifiers when you use those sign-in methods, authentication tokens.",
        "Creator profile: Instagram/TikTok handles, city, audience metrics, niches, languages, membership status, collaboration history.",
        "Venue profile (if applicable): venue name, area, campaign details, owner contact information.",
        "Location data: approximate device location when you use map or nearby features (only while the app is in use and permission is granted).",
        "Collaboration data: bookings, check-in codes, proof links, optional proof screenshots, timestamps, strike records.",
        "Communications: support messages, safety reports, deletion requests.",
        "Technical data: app version, device type, IP address in server logs (via hosting providers).",
      ],
    },
    {
      id: "not-collected",
      title: "Data we do not collect",
      bullets: [
        "We do not sell your personal data.",
        "We do not use third-party advertising trackers in the iOS or Android apps.",
        "We do not collect precise background location.",
        "We do not require access to your contacts or microphone for core features.",
      ],
    },
    {
      id: "purposes",
      title: "How we use your data",
      bullets: [
        "Create and secure your account.",
        "Review membership applications and maintain marketplace quality.",
        "Match creators with venue campaigns and manage bookings.",
        "Verify attendance (check-in) and proof of deliverables.",
        "Send operational notifications and optional local reminders.",
        "Enforce Community Guidelines, issue strikes, and resolve disputes.",
        "Comply with legal obligations and respond to lawful requests.",
      ],
    },
    {
      id: "legal-basis",
      title: "Legal basis",
      paragraphs: [
        "We process data based on contract performance (providing the Service), legitimate interests (fraud prevention, safety, product improvement), and consent where required (e.g. location permission, optional notifications).",
        "For users in Turkey, we comply with KVKK (Law No. 6698). For users in the EU/EEA, we comply with GDPR.",
      ],
    },
    {
      id: "sharing",
      title: "Sharing and processors",
      paragraphs: [
        "We share data only as needed to operate the Service:",
      ],
      bullets: [
        "Supabase — authentication, database, file storage (proof uploads).",
        "Apple — Sign in with Apple authentication.",
        "Vercel — website hosting.",
        "Stripe — venue Partner subscriptions and Featured Boost payments (venues only; no creator IAP).",
        "Resend — transactional email.",
        "Mapbox — map tiles when map features are used.",
      ],
    },
    {
      id: "retention",
      title: "Retention",
      bullets: [
        "Account and profile data: retained while your account is active.",
        "Proof submissions: up to 24 months for dispute resolution, then deleted or anonymized.",
        "Server logs: typically up to 90 days.",
        "Deletion requests: retained only as long as needed to complete verification and audit the request.",
      ],
    },
    {
      id: "rights",
      title: "Your rights",
      paragraphs: [
        "Depending on your jurisdiction, you may request access, correction, portability, restriction, objection, or deletion of your personal data.",
        "Delete your account in the iOS or Android app (Profile), at https://marvisociety.com/delete-account, or email support@marvisociety.com.",
      ],
    },
    {
      id: "children",
      title: "Age requirement",
      paragraphs: [
        "Marvi Society is for users aged 18 and over. We do not knowingly collect data from anyone under 18.",
      ],
    },
    {
      id: "security",
      title: "Security",
      paragraphs: [
        "We use industry-standard measures including encrypted transport (HTTPS/TLS), access controls, row-level security in our database, and least-privilege administrative access.",
      ],
    },
    {
      id: "changes",
      title: "Changes to this policy",
      paragraphs: [
        "We may update this policy. Material changes will be posted on this page with an updated date. Continued use after changes constitutes acceptance.",
      ],
    },
  ],
  contactNote: "Privacy questions: support@marvisociety.com",
};

const privacyTr: LegalDocument = {
  title: "Gizlilik Politikası",
  subtitle: "Son güncelleme: 10 Haziran 2026",
  intro:
    "Marvi Society (“Marvi”, “biz”), onaylı içerik üreticileri ile doğrulanmış mekan ortaklarını bir araya getiren özel, davetle üyelik tabanlı bir iş birliği platformudur. Bu politika hangi kişisel verileri topladığımızı, neden topladığımızı ve haklarınızı açıklar.",
  sections: [
    {
      id: "controller",
      title: "Veri sorumlusu",
      paragraphs: ["Marvi Society, iOS ve Android uygulamaları ile web sitesi üzerinden işlenen kişisel verilerin sorumlusudur.", "İletişim: support@marvisociety.com"],
    },
    {
      id: "data-collected",
      title: "Toplanan veriler",
      bullets: [
        "Hesap: e-posta, ad, Apple veya Google ile giriş tanımlayıcıları.",
        "Üretici profili: Instagram/TikTok, şehir, kitle metrikleri, nişler, üyelik durumu.",
        "Konum: yalnızca uygulama kullanımı sırasında ve izin verildiğinde yaklaşık konum.",
        "İş birliği: rezervasyonlar, check-in kodları, kanıt linkleri, ekran görüntüleri.",
        "Teknik: uygulama sürümü, cihaz türü, sunucu günlükleri.",
      ],
    },
    {
      id: "purposes",
      title: "Kullanım amaçları",
      bullets: [
        "Hesap oluşturma ve güvenlik.",
        "Üyelik incelemesi ve eşleştirme.",
        "Rezervasyon ve kanıt süreçleri.",
        "Topluluk kuralları ve güvenlik.",
        "Yasal yükümlülükler.",
      ],
    },
    {
      id: "legal-basis",
      title: "Hukuki dayanak",
      paragraphs: ["KVKK ve ilgili mevzuata uygun olarak sözleşmenin ifası, meşru menfaat ve açık rıza temellerine dayanırız."],
    },
    {
      id: "sharing",
      title: "Aktarım ve işleyiciler",
      bullets: ["Supabase (barındırma ve veritabanı)", "Apple (kimlik doğrulama)", "Vercel (web sitesi)"],
    },
    {
      id: "rights",
      title: "Haklarınız",
      paragraphs: [
        "KVKK kapsamında erişim, düzeltme, silme ve itiraz haklarına sahipsiniz.",
        "Hesap silme: https://marvisociety.com/delete-account",
      ],
    },
    {
      id: "children",
      title: "Yaş sınırı",
      paragraphs: ["Platform yalnızca 18 yaş ve üzeri kullanıcılar içindir."],
    },
  ],
  contactNote: "Gizlilik: support@marvisociety.com",
};

const termsEn: LegalDocument = {
  title: "Terms of Service",
  subtitle: "Last updated: 1 September 2026",
  intro:
    "These Terms of Service (“Terms”) govern your access to Marvi Society’s iOS and Android applications, website, and related services (collectively, the “Service”). By creating an account or using the Service, you agree to these Terms and our Privacy Policy.",
  sections: [
    {
      id: "service",
      title: "The Service",
      paragraphs: [
        "Experiences are typically provided in exchange for agreed social content (barter). Venues may pay Marvi for Partner access and Featured Boost placement via Stripe on the web portal. Creators are not charged in-app. Marvi does not guarantee bookings, reach, or revenue.",
      ],
    },
    {
      id: "eligibility",
      title: "Eligibility",
      bullets: [
        "You must be at least 18 years old. We store the timestamp of this confirmation on your account (`age_confirmed_at`). Product eligibility is 18+ even though Apple rates the iOS app 17+ (nearest nightlife / UGC bucket).",
        "Creator access requires admin approval. Invite codes are optional growth tools, not a signup gate.",
        "You must provide accurate profile information.",
        "One person per creator account; no account sharing.",
      ],
    },
    {
      id: "membership",
      title: "Membership and approval",
      paragraphs: [
        "We may approve, pause, or reject applications at our discretion. Paused or terminated members lose access to new invitations.",
      ],
    },
    {
      id: "creator-duties",
      title: "Creator obligations",
      bullets: [
        "Honor confirmed bookings or cancel promptly through the app.",
        "Arrive within the agreed window and follow venue rules.",
        "Submit proof links/screenshots before the stated deadline.",
        "Disclose sponsored content per Turkish and applicable advertising laws (#reklam, paid partnership labels).",
        "Do not harass venue staff or other members.",
      ],
    },
    {
      id: "venue-duties",
      title: "Venue obligations",
      bullets: [
        "Publish accurate campaign descriptions, slots, and deliverables.",
        "Provide the agreed experience safely and professionally.",
        "Issue valid check-in codes only to confirmed creators.",
        "Review proof submissions fairly and promptly.",
      ],
    },
    {
      id: "content",
      title: "User content and license",
      paragraphs: [
        "You retain ownership of content you create. You grant Marvi a limited license to display proof links and metadata inside the Service for verification, dispute resolution, and quality assurance.",
      ],
    },
    {
      id: "strikes",
      title: "Strikes and termination",
      bullets: [
        "No-shows, missed proof deadlines, fraud, or policy violations may result in strikes.",
        "Repeated violations may lead to paused or terminated membership without refund (the Service is free for creators).",
        "We may remove campaigns or accounts that harm marketplace trust.",
      ],
    },
    {
      id: "prohibited",
      title: "Prohibited conduct",
      bullets: [
        "Fake followers, bots, or misrepresented audience metrics.",
        "Circumventing invite or approval systems.",
        "Uploading unlawful, hateful, or non-consensual content.",
        "Scraping, reverse engineering, or attacking the platform.",
      ],
    },
    {
      id: "liability",
      title: "Disclaimers and liability",
      paragraphs: [
        "THE SERVICE IS PROVIDED “AS IS”. TO THE MAXIMUM EXTENT PERMITTED BY LAW, MARVI IS NOT LIABLE FOR INDIRECT DAMAGES OR DISPUTES BETWEEN CREATORS AND VENUES. OUR ROLE IS CURATION, MATCHING, AND MODERATION — NOT GUARANTEEING OUTCOMES.",
      ],
    },
    {
      id: "law",
      title: "Governing law",
      paragraphs: [
        "These Terms are governed by the laws of the Republic of Turkey, without regard to conflict-of-law rules. Courts in Istanbul shall have jurisdiction unless mandatory consumer protection law provides otherwise.",
      ],
    },
  ],
  contactNote: "Legal inquiries: support@marvisociety.com",
};

const termsTr: LegalDocument = {
  title: "Kullanım Şartları",
  subtitle: "Son güncelleme: 1 Eylül 2026",
  intro:
    "Bu şartlar Marvi Society uygulaması ve web sitesinin kullanımını düzenler. Deneyimler genellikle barter’dır; mekânlar Partner ve Featured Boost için web portalında Stripe ile Marvi’ye öder. Creator’lardan uygulama içi ücret alınmaz.",
  sections: [
    {
      id: "eligibility",
      title: "Uygunluk",
      bullets: [
        "18 yaş ve üzeri olmalısınız. Bu onayın zaman damgası hesapta saklanır (`age_confirmed_at`). Apple iOS uygulamasını 17+ derecelendirir; ürün uygunluğu 18+’tır.",
        "Creator erişimi admin onayı ister. Davet kodları isteğe bağlıdır, kayıt kapısı değildir.",
        "Doğru profil bilgisi sağlamalısınız.",
      ],
    },
    {
      id: "creator-duties",
      title: "İçerik üreticisi yükümlülükleri",
      bullets: [
        "Onaylanan rezervasyonlara katılın veya uygulama üzerinden iptal edin.",
        "Kanıt linklerini süresi içinde gönderin.",
        "Reklam içeriklerini ilgili mevzuata uygun şekilde etiketleyin (#reklam).",
      ],
    },
    {
      id: "strikes",
      title: "İhlaller ve askıya alma",
      paragraphs: ["Gelmeme, kanıt gecikmesi veya politika ihlalleri uyarı veya üyelik askıya alınmasına yol açabilir."],
    },
    {
      id: "law",
      title: "Uygulanacak hukuk",
      paragraphs: ["Türkiye Cumhuriyeti kanunları uygulanır. İstanbul mahkemeleri yetkilidir."],
    },
  ],
  contactNote: "Hukuki sorular: support@marvisociety.com",
};

const guidelinesEn: LegalDocument = {
  title: "Community Guidelines",
  subtitle: "Last updated: 10 August 2026",
  intro:
    "Marvi Society is a trust-based club. These guidelines apply to all creators, venues, and operators. Violations may result in strikes, paused membership, or removal.",
  sections: [
    {
      id: "respect",
      title: "Respect and safety",
      bullets: [
        "Treat venues, staff, and fellow creators with respect.",
        "No harassment, discrimination, or threats.",
        "Report safety concerns immediately to support@marvisociety.com.",
      ],
    },
    {
      id: "child-safety",
      title: "Child safety and CSAE prohibition",
      paragraphs: [
        "Marvi Society is for adults 18+. We have a zero-tolerance policy against child sexual abuse and exploitation (CSAE) and child sexual abuse material (CSAM).",
        "Any content, account, or conduct that involves the sexualization, exploitation, or endangerment of minors is prohibited and will result in immediate removal and reporting to the appropriate authorities (including NCMEC or the relevant regional authority where required by law).",
      ],
      bullets: [
        "Do not upload, share, request, or solicit CSAM or any sexual content involving minors.",
        "Do not attempt to contact, groom, or exploit minors through the Service.",
        "We remove CSAM and CSAE-related material promptly after obtaining actual knowledge of it.",
        "Child safety point of contact: support@marvisociety.com (subject: “Child safety / CSAE”).",
      ],
    },
    {
      id: "authenticity",
      title: "Authenticity",
      bullets: [
        "Use your real social accounts and accurate audience data.",
        "Do not purchase engagement to qualify for invitations.",
        "Proof must reflect genuine visits and agreed deliverables.",
      ],
    },
    {
      id: "content-standards",
      title: "Content standards",
      bullets: [
        "Follow venue photography rules and guest privacy.",
        "No illegal content, hate speech, or explicit material in proof submissions.",
        "Disclose commercial relationships clearly on social platforms.",
      ],
    },
    {
      id: "reporting",
      title: "Reporting and in-app feedback",
      paragraphs: [
        "Users can report safety concerns in the Marvi Society app (Profile → Support / report flows) and by emailing support@marvisociety.com with subject “Safety report”, including relevant booking details. We review reports within 2 business days and take enforcement action consistent with these standards and applicable law.",
      ],
    },
  ],
  contactNote: "Report issues / child safety: support@marvisociety.com",
};

const guidelinesTr: LegalDocument = {
  title: "Topluluk Kuralları",
  subtitle: "Son güncelleme: 10 Ağustos 2026",
  intro: "Güvene dayalı bir topluluğuz. Bu kurallar tüm üyeler için geçerlidir.",
  sections: [
    {
      id: "respect",
      title: "Saygı ve güvenlik",
      bullets: ["Mekan personeline ve diğer üyelere saygılı davranın.", "Taciz veya tehdit yasaktır."],
    },
    {
      id: "child-safety",
      title: "Çocuk güvenliği ve CSAE yasağı",
      paragraphs: [
        "Marvi Society yalnızca 18+ kullanıcılar içindir. Çocuk cinsel istismarı ve sömürüsü (CSAE) ile çocuk cinsel istismar materyaline (CSAM) karşı sıfır tolerans politikamız vardır.",
        "Küçükleri cinsel içerikle ilişkilendiren, sömüren veya tehlikeye atan her türlü içerik, hesap veya davranış yasaktır; derhal kaldırma ve yetkili mercilere bildirim uygulanır.",
      ],
      bullets: [
        "CSAM yüklemeyin, paylaşmayın, talep etmeyin.",
        "Hizmet üzerinden küçüklerle iletişim kurmaya veya onları sömürmeye çalışmayın.",
        "CSAM/CSAE içeriği öğrenildiğinde derhal kaldırılır.",
        "Çocuk güvenliği iletişim noktası: support@marvisociety.com (konu: “Child safety / CSAE”).",
      ],
    },
    {
      id: "authenticity",
      title: "Özgünlük",
      bullets: ["Gerçek hesaplarınızı kullanın.", "Kanıtlar gerçek ziyaretleri yansıtmalıdır."],
    },
    {
      id: "reporting",
      title: "Şikayet ve uygulama içi bildirim",
      paragraphs: [
        "Uygulama içinden (Profil → Destek / rapor) veya support@marvisociety.com adresine “Safety report” konulu e-posta ile bildirim yapabilirsiniz.",
      ],
    },
  ],
  contactNote: "Şikayet / çocuk güvenliği: support@marvisociety.com",
};

const cookiesEn: LegalDocument = {
  title: "Cookie Policy",
  subtitle: "Last updated: 31 August 2026",
  intro:
    "This policy explains how Marvi Society uses cookies and similar storage on marvisociety.com. The iOS and Android apps do not use third-party advertising cookies.",
  sections: [
    {
      id: "essential",
      title: "Essential cookies",
      paragraphs: [
        "We use essential cookies and local storage to keep you signed in to the venue portal and admin console, remember your language (EN/TR), and protect forms from abuse.",
      ],
    },
    {
      id: "analytics",
      title: "Analytics",
      paragraphs: [
        "If you choose “Accept all”, we may record product analytics events (page and in-app style events) to improve the Service. If you choose “Essential only”, we do not send those analytics events from this browser.",
      ],
    },
    {
      id: "payments",
      title: "Payments",
      paragraphs: [
        "Venue Partner and Featured Boost checkout is processed by Stripe. Stripe may set its own cookies on hosted Checkout pages subject to Stripe’s policy.",
      ],
    },
    {
      id: "choices",
      title: "Your choices",
      paragraphs: [
        "Use the cookie banner to accept all or essential-only. You can clear site data in your browser to reset the choice. Contact support@marvisociety.com for questions.",
      ],
    },
  ],
  contactNote: "Cookies: support@marvisociety.com",
};

const cookiesTr: LegalDocument = {
  title: "Çerez Politikası",
  subtitle: "Son güncelleme: 31 Ağustos 2026",
  intro:
    "Bu politika marvisociety.com üzerindeki çerez ve benzeri depolamayı açıklar. iOS ve Android uygulamalarında üçüncü taraf reklam çerezi kullanılmaz.",
  sections: [
    {
      id: "essential",
      title: "Zorunlu çerezler",
      paragraphs: [
        "Portal ve admin oturumu, dil tercihi (EN/TR) ve form koruması için zorunlu çerez / yerel depolama kullanırız.",
      ],
    },
    {
      id: "analytics",
      title: "Analitik",
      paragraphs: [
        "“Tümünü kabul et” derseniz ürün analitik olayları kaydedilebilir. “Yalnızca zorunlu” derseniz bu tarayıcıdan analitik gönderilmez.",
      ],
    },
    {
      id: "payments",
      title: "Ödemeler",
      paragraphs: [
        "Mekân Partner ve Featured Boost ödemeleri Stripe üzerinden işlenir. Stripe, kendi Checkout sayfalarında kendi çerez politikasını uygulayabilir.",
      ],
    },
    {
      id: "choices",
      title: "Tercihleriniz",
      paragraphs: [
        "Banner’dan tümünü kabul veya yalnızca zorunlu seçebilirsiniz. Tercihi sıfırlamak için tarayıcı site verisini temizleyin.",
      ],
    },
  ],
  contactNote: "Çerezler: support@marvisociety.com",
};

export const legalDocuments = {
  privacy: { en: privacyEn, tr: privacyTr },
  terms: { en: termsEn, tr: termsTr },
  guidelines: { en: guidelinesEn, tr: guidelinesTr },
  cookies: { en: cookiesEn, tr: cookiesTr },
} as const;

export type LegalDocumentKey = keyof typeof legalDocuments;

export function getLegalDocument(key: LegalDocumentKey, locale: LegalLocale): LegalDocument {
  return legalDocuments[key][locale] ?? legalDocuments[key].en;
}
