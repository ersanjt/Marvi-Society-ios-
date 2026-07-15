# راهنمای جامع اپلیکیشن Marvi Society

> فایل مرجع کامل دربارهٔ «Marvi Society چیست، چه‌کار می‌کند، و ساختار کدش چطور است».
> این سند وضعیت **واقعی کدبیس** را توصیف می‌کند (نه صرفاً طراحی آرمانی). آخرین به‌روزرسانی: تیر ۱۴۰۵ / July 2026.

---

## فهرست

1. [Marvi Society چیست و هدفش چیست](#۱-marvi-society-چیست-و-هدفش-چیست)
2. [نقش‌های کاربری](#۲-نقشهای-کاربری)
3. [مدل‌های همکاری](#۳-مدلهای-همکاری-collaboration-models)
4. [سفر کاربر و چرخهٔ حیات رزرو](#۴-سفر-کاربر-و-چرخهٔ-حیات-رزرو)
5. [ساختار کلی پروژه (Monorepo)](#۵-ساختار-کلی-پروژه-monorepo)
6. [معماری کلاینت‌ها](#۶-معماری-کلاینتها)
7. [بک‌اند: Supabase](#۷-بکاند-supabase)
8. [احراز هویت](#۸-احراز-هویت-authentication)
9. [لایهٔ وب (Next.js)](#۹-لایهٔ-وب-nextjs)
10. [بین‌المللی‌سازی و زبان](#۱۰-بینالمللیسازی-و-زبان-i18n)
11. [سیستم طراحی (Design System)](#۱۱-سیستم-طراحی-design-system)
12. [جریان عملیات و انتشار (Ops)](#۱۲-جریان-عملیات-و-انتشار-ops)
13. [نقشهٔ فایل‌های کلیدی](#۱۳-نقشهٔ-فایلهای-کلیدی)
14. [یک جریان کامل از UI تا دیتابیس (مثال: پذیرش پیشنهاد)](#۱۴-یک-جریان-کامل-از-ui-تا-دیتابیس)
15. [وضعیت فعلی هر پلتفرم](#۱۵-وضعیت-فعلی-هر-پلتفرم)

---

## ۱. Marvi Society چیست و هدفش چیست

**Marvi Society** یک **بازارگاه خصوصی و تأییدشده توسط ادمین (private, admin-approved marketplace)** است که **سازندگان محتوا (creators / influencers)** را به **مکان‌های تأییدشده (venues)** — رستوران، کافه، کلاب، مرکز زیبایی، باشگاه، فروشگاه و... — برای **همکاری‌های ساختاریافته** وصل می‌کند.

مدل کسب‌وکار **تهاتری (barter)** است: مکان یک تجربه (وعدهٔ غذا، خدمت، محصول، رویداد) ارائه می‌دهد و سازنده در ازای آن **محتوای اجتماعی توافق‌شده** (استوری، پست، ریویو) تولید می‌کند. در نسخهٔ v1 **هیچ پرداخت نقدی مستقیمی** بین سازنده و مکان وجود ندارد.

- شهر اولیه: **استانبول** (قابل گسترش به شهرهای دیگر).
- زبان اصلی رابط کاربری: **ترکی استانبولی** (به‌همراه انگلیسی).
- محصولات معیار (benchmark): [Collabb](https://collabb.me/) و [The Secret Society](https://www.the-secret-society.com/).

**مدل دسترسی:** ثبت‌نام با ایمیل / Apple / Google ← افزودن اکانت Instagram یا TikTok ← **انتظار برای تأیید ادمین**. کدهای دعوت/معرف (invite/referral) ابزار رشدِ اختیاری‌اند که ادمین صادر می‌کند، نه دروازهٔ اجباری عضویت.

هدف نهایی: ساختن یک **حلقهٔ اعتماد و کیفیت** — ادمین کیفیت سازندگان و مکان‌ها را کنترل می‌کند؛ مکان‌ها محتوای قابل‌اتکا می‌گیرند؛ سازندگان تجربه‌های منتخب دریافت می‌کنند.

---

## ۲. نقش‌های کاربری

اپلیکیشن سه فضای کاری (workspace) بر اساس نقش دارد و رابط کاربری بر اساس نقش عوض می‌شود:

| نقش | چه زمانی فعال است | تب‌های اصلی |
|-----|------------------|-------------|
| **Creator (سازنده)** | حالت پیش‌فرض بعد از onboarding | Explore (کشف)، Community (انجمن)، My Events (رویدادهای من / Bookings)، Profile |
| **Venue (مکان)** | وقتی یک `venue_profiles` به حساب متصل باشد | Studio، Community، Inbox، Account |
| **Admin (ادمین)** | وقتی `profiles.role = admin` باشد | Admin console، Inbox، Account |

نقش در کلاینت از طریق RPC `fetch_account_context` تعیین می‌شود و در iOS/Android از طریق منطق «allowed workspaces» به تب‌ها ترجمه می‌شود.

---

## ۳. مدل‌های همکاری (Collaboration Models)

هر پیشنهاد (offer) یکی از چهار مدل زیر را دارد (enum: `collaboration_model`). چرخهٔ حیات رزرو مشترک است ولی زمان‌بندی، ظرفیت و پنجرهٔ اثبات (proof) فرق می‌کند:

| مدل | کد | جریان سازنده | کاربرد مکان |
|-----|----|--------------|-------------|
| **Invitation (دعوت)** | `invitation` | درخواست ← تأیید ← مراجعه در تایم‌اسلات | رستوران، سالن، مراجعهٔ زمان‌بندی‌شده |
| **Event (رویداد)** | `event` | RSVP (اعلام تعداد میهمان) ← حضور گروهی | افتتاحیه، نمایش خصوصی، شب کلاب |
| **Gift (هدیه)** | `gift` | دریافت محصول (با آدرس ارسال) ← تولید محتوا | خرده‌فروشی، باکس زیبایی، product seeding |
| **Instant (فوری)** | `instant` | نقشه ← پذیرش ← مراجعهٔ فوری | کافه، مراجعهٔ حضوری بدون قرار |

در رابط کاربری، صفحهٔ جزئیات پیشنهاد (`OfferDetail`) بسته به مدل، شیت متفاوتی هنگام پذیرش نشان می‌دهد: برای **gift** فیلد آدرس ارسال، برای **event** انتخاب تعداد میهمان.

---

## ۴. سفر کاربر و چرخهٔ حیات رزرو

### سفر سازنده (Creator)

```text
Onboarding → (Instagram/TikTok + شهر + تأیید ۱۸+ و شرایط)
    → انتظار تأیید ادمین (status = under_review)
    → Explore: مرور کمپین‌های زنده، فیلتر، ذخیره، مشاهدهٔ بریف
    → Accept: رزرو یک اسلات → در My Events ظاهر می‌شود
    → Check-in: وارد کردن کد ۴ رقمی در مکان
    → Proof: ارسال لینک استوری/پست/ریویو (+ اسکرین‌شات اختیاری)
    → Rate venue: ارزیابی مکان بعد از بازدید
```

### سفر مکان (Venue)

```text
Campaign builder → ثبت کمپین برای بررسی ادمین
    → Studio: مشاهدهٔ کمپین‌ها، صف بازبینی سازندگان (creator review queue)،
      رابط swipe برای انتخاب سازنده (shortlist/pass)
    → Inbox: اعلان‌های عملیاتی
    → دعوت مستقیم سازنده به همکاری (collaboration_requests)
```

### سفر ادمین (Admin)

```text
Review queue → تأیید/رد درخواست سازنده، کمپین، proof
    → صدور کد دعوت، اعمال strike، تغییر وضعیت عضویت
    → ارسال اعلان/ایمیل، broadcast
```

### ماشین حالت رزرو (Booking State Machine)

enum `booking_stage`:

```text
invited → confirmed → checked_in → proof_due → completed
   │          │            │            │
   └──────────┴────────────┴────────────┴──────────→ cancelled
```

گذارها **سمت سرور** با RPCها اعمال می‌شوند (نه در کلاینت):

- `confirmed`: سازنده پیشنهاد را می‌پذیرد (`accept_offer`) یا مکان دعوت را تأیید می‌کند (`venue_confirm_booking`).
- `checked_in`: کد معتبر check-in (`check_in_booking`).
- `proof_due`: بعد از پنجرهٔ بازدید.
- `completed`: proof تأیید شود.
- `cancelled`: `cancel_booking` — ممکن است strike بزند.

---

## ۵. ساختار کلی پروژه (Monorepo)

```text
marvi-society/            (ریشه؛ npm workspaces)
├── apps/
│   ├── ios/              # اپ SwiftUI (کلاینت اصلی)
│   ├── android/          # اپ Kotlin + Jetpack Compose
│   └── web/              # Next.js 15 (مارکتینگ + پرتال مکان + کنسول ادمین)
├── packages/
│   ├── api-contract/     # OpenAPI 3.1 (قرارداد API)
│   └── shared/           # کد/تایپ مشترک وب
├── infra/
│   └── supabase/         # migrations، RLS، RPC، seed، combined SQL
├── docs/                 # مستندات (این فایل اینجاست)
├── scripts/              # اسکریپت‌های ops، release، app-store، google-play
├── release/              # manifest.json (نسخه‌ها + لاگ sync)
└── package.json          # اسکریپت‌های ریشه (sync, status, testflight, ...)
```

مدیریت با **npm workspaces** انجام می‌شود و اسکریپت‌های سراسری در `package.json` ریشه هستند.

---

## ۶. معماری کلاینت‌ها

هر دو کلاینت موبایل الگوی مشترکی دارند:

```text
View / Composable            (لایهٔ نمایش)
      ↓
AppState / AppViewModel      (state رابط کاربری + منطق)
      ↓
MarviAPI / MarviRepository   (لایهٔ دسترسی به داده)
      ↓
SupabaseClient               (REST + Auth + Storage روی Supabase)
      ↓
Supabase (Postgres + RLS + RPC + Storage)
```

نکتهٔ مهم: هیچ‌کدام از کلاینت‌ها از **SDK رسمی Supabase** استفاده نمی‌کنند؛ هر دو یک کلاینت REST سبک و دست‌ساز دارند که مستقیماً با PostgREST و Auth API حرف می‌زند. این باعث سبکی و کنترل کامل روی درخواست‌ها می‌شود.

### ۶.۱ کلاینت iOS (SwiftUI)

- **زبان/فریم‌ورک:** Swift + SwiftUI، بدون وابستگی SPM خارجی برای شبکه.
- **نقطهٔ ورود:** `apps/ios/MarviSociety/App/MarviSocietyApp.swift` (`@main`) → `ContentView` → `MainAppShell`.
- **State مرکزی:** `App/AppState.swift` یک `ObservableObject` بزرگ است که کل state اپ (پروفایل، پیشنهادها، رزروها، زبان، وضعیت sync و...) و منطق کسب‌وکار را نگه می‌دارد و از طریق `@EnvironmentObject` در دسترس ویوها است.
- **لایهٔ API:** پروتکل `Core/Networking/MarviAPI.swift` قرارداد را تعریف می‌کند؛ `Core/Networking/Supabase/SupabaseMarviAPI.swift` آن را با فراخوانی RPCها پیاده می‌کند.
- **کلاینت شبکه:** `Core/Networking/Supabase/SupabaseClient.swift` یک `actor` مبتنی بر `URLSession` است («Lightweight Supabase REST + Auth client, no SPM dependency»). متدهای `rpc`, `patch`, `select`, `signInWith...` را دارد.
- **پایداری/Session:** `Core/Persistence/SessionKeychain.swift` توکن‌ها را در Keychain نگه می‌دارد؛ `AppPersistence.swift` snapshot اپ را ذخیره می‌کند.
- **سرویس‌ها:** `LocationService` (موقعیت برای نقشه/nearby)، `PushNotificationService` (توکن APNs + یادآور محلی)، `AppleSignInService`، `GoogleSignInService`.
- **قابلیت‌ها (Features):** هر بخش در `Features/` — `Discover`, `MapDiscover`, `OfferDetail`, `Bookings` (+ `CollaborationChatView`), `Community`, `Profile`, `VenueStudio`, `Admin`, `Inbox`, `Onboarding`.
- **نقشه:** `MapDiscoverView` (MapKit بومی iOS).
- **زبان:** `Core/MarviL10n.swift`.

### ۶.۲ کلاینت Android (Jetpack Compose)

- **زبان/فریم‌ورک:** Kotlin + Jetpack Compose (Material 3).
- **نقطهٔ ورود:** `MainActivity.kt` → `ui/MarviApp.kt` که `NavHost` و `NavigationBar` را می‌سازد.
- **State مرکزی:** `ui/viewmodel/AppViewModel.kt` (یک `AndroidViewModel`) معادل `AppState` در iOS است؛ با `AppViewModelFactory` ساخته می‌شود. State با `mutableStateOf` نگه‌داری می‌شود.
- **لایهٔ داده:** `network/MarviRepository.kt` تمام فراخوانی‌های RPC/REST را کپسوله می‌کند.
- **کلاینت شبکه:** `network/SupabaseClient.kt` مبتنی بر **Ktor** (`ktor-client-android`) + `kotlinx.serialization`؛ متدهای `rpcJson`, `select`, `patch`, `post`, و کمکی‌های JSON.
- **پایداری/Session:** `data/SessionStore.kt` با **DataStore** (Preferences).
- **مدل‌ها:** `data/Models.kt` (data classها) و `data/SampleData.kt` (دادهٔ نمونهٔ حالت دمو).
- **آپلود عکس:** `network/ImageUploadHelper.kt`؛ ورود گوگل: `network/GoogleOAuth.kt`.
- **UI:** `ui/screens/*` (هر صفحه)، `ui/components/MarviComponents.kt` (کامپوننت‌های مشترک)، `ui/theme/*` (رنگ/گرادیان/تم)، `ui/OfferImagery.kt`.
- **نقشه:** `ui/screens/MapDiscoverScreen.kt` با **osmdroid (OpenStreetMap)** — عمداً به‌جای Google Maps SDK انتخاب شده تا روی دستگاه‌های بدون Google Play Services (مثل TECNO KM8n تست) هم کار کند.
- **بارگذاری تصویر:** کتابخانهٔ **Coil**.
- **زبان:** `l10n/MarviL10n.kt`.

**وابستگی‌های کلیدی Android** (از `apps/android/app/build.gradle.kts`): Compose BOM، Material 3 + material-icons-extended، navigation-compose، lifecycle-viewmodel-compose، datastore-preferences، coil-compose، osmdroid، ktor client + kotlinx-serialization.

---

## ۷. بک‌اند: Supabase

کل بک‌اند روی **Supabase** (Postgres مدیریت‌شده) است. منطق کسب‌وکار عمدتاً در **توابع RPC (PL/pgSQL)** پیاده شده و امنیت با **Row Level Security (RLS)** روی همهٔ جدول‌ها اعمال می‌شود.

- **Migrations:** `infra/supabase/migrations/*.sql` (حدود **۴۶** فایل). یک فایل ترکیبی `infra/supabase/ALL_MIGRATIONS_COMBINED.sql` هم با اسکریپت ساخته می‌شود.
- **جدول‌ها (حدود ۳۲):** اصلی‌ترین‌ها:
  - هویت/پروفایل: `profiles`, `creator_profiles`, `venue_profiles`
  - بازارگاه: `offers`, `bookings`, `proof_submissions`, `saved_offers`
  - همکاری/انتخاب: `collaboration_requests`, `creator_shortlists`, `creator_passes`
  - ارزیابی/کیفیت: `venue_reviews`, `creator_reviews`, `strikes`
  - پیام‌رسانی: `conversations`, `messages` (چت همکاری مبتنی بر رزرو)، `direct_threads`, `direct_messages` (پیام مستقیم انجمن)
  - انجمن/گراف اجتماعی: `follows`, `activity_events`, `profile_comments`, `creator_showcase`
  - عملیات: `admin_tasks`, `notifications`, `referral_codes`, `analytics_events`
  - زیرساخت پیام: `email_outbox`, `push_outbox`, `device_tokens`, `deletion_requests`, `contact_messages`, `demo_requests`, `user_location_snapshots`, `marvi_runtime_settings`
- **Enumها (۹):** `user_role`, `membership_status`, `offer_category`, `offer_status`, `collaboration_model`, `booking_stage`, `proof_status`, `admin_task_status`, `admin_task_type`.
- **توابع RPC (حدود ۹۰):** نمونه‌های مهم:
  - بازارگاه: `accept_offer`, `cancel_booking`, `check_in_booking`, `submit_proof`, `toggle_saved_offer`, `venue_confirm_booking`
  - ارزیابی: `submit_creator_review`, `submit_venue_review`, `fetch_venue_review_queue`, `issue_strike_for_booking`
  - همکاری/پیام: `creator_accept_collaboration`, `get_my_pending_collaboration_requests`, `get_my_conversations`, `get_conversation_messages`, `send_message`, `ensure_conversation_for_booking`
  - انجمن: `follow_user`, `unfollow_user`, `search_members`, `get_following_activity`, `add_profile_comment`, `get_my_showcase`
  - حساب: `fetch_account_context`, `ensure_creator_profile`, `pause_own_account`, `reactivate_own_account`, `delete_own_account`, `validate_referral_code`, `redeem_referral_code`
  - ادمین: `admin_list_users`, `admin_set_membership_status`, `admin_create_invite_code`, `admin_send_email/notification`, `resolve_admin_task`
  - زیرساخت: `handle_new_user` (trigger عضو جدید)، `is_admin`, `queue_push_notification`, `queue_transactional_email`, `dispatch_email_outbox`
- **Storage:** باکت‌های عمومی برای رسانه — `profile-media` (آواتار/کاور)، `venue-media`، و مسیر proof.
- **ایمیل/پوش:** به‌جای Edge Functions، از الگوی **outbox** (جدول‌های `email_outbox`/`push_outbox` + توابع dispatch) استفاده می‌شود.

**نکتهٔ عملیاتی مهم:** چون migrationها با `supabase db push` روی ریموت ثبت می‌شوند، **ویرایش یک فایل migration که قبلاً apply شده باعث drift می‌شود** (رکورد ثبت است ولی DDL جدید اجرا نمی‌شود). راه درست: همیشه یک migration جدید بسازید (مثل `20260715000001_repair_venue_reviews.sql`).

---

## ۸. احراز هویت (Authentication)

- روش‌ها: **Sign in with Apple**، **Google Sign-In**، **Email + Password / OTP**.
- جریان: Supabase Auth توکن JWT صادر می‌کند؛ کلاینت‌ها JWT را در هدر `Authorization: Bearer` می‌فرستند.
- در iOS توکن‌ها در **Keychain**، در Android در **DataStore** ذخیره می‌شوند.
- تریگر `handle_new_user` هنگام ساخت کاربر، رکورد `profiles`/`creator_profiles` را می‌سازد.
- **RLS** بر اساس `auth.uid()` و تابع `is_admin()` دسترسی هر نقش را محدود می‌کند: سازنده فقط پروفایل/رزروهای خودش و پیشنهادهای زندهٔ شهرش؛ مکان فقط venue خودش؛ ادمین دسترسی کامل.
- دروازه‌ها (gates): تا زمان تأیید ادمین `status = under_review`؛ برای پذیرش پیشنهاد باید Instagram یا TikTok ثبت شده باشد.

---

## ۹. لایهٔ وب (Next.js)

`apps/web` روی **Next.js 15 + React 19 + Tailwind + Supabase SSR** است و با App Router و route groups سه سطح دارد:

```text
src/app/
  (marketing)/   → صفحات عمومی: خانه، creators، brands، faq، privacy، terms،
                   community-guidelines، delete-account، contact، invite، auth/*
  (portal)/      → پرتال مکان (نیاز به لاگین): dashboard، campaigns/new،
                   creators، reviews، login
  (admin)/       → کنسول ادمین (نقش admin): صف بررسی، users، broadcast
  api/           → مسیرهای BFF و webhook: admin/*، portal/*، analytics،
                   contact، delete-account، demo، health
```

کاربردهای کلیدی وب: سایت مارکتینگ + صفحات حقوقی (الزامی App Store)، **حذف حساب** (الزام Apple)، callback احراز هویت (از جمله `auth/ios-callback`)، و پرتال/کنسول ادمین به‌عنوان جایگزین وبِ عملیات.

---

## ۱۰. بین‌المللی‌سازی و زبان (i18n)

- زبان پیش‌فرض رابط کاربری: **ترکی استانبولی**؛ زبان دوم: **انگلیسی**.
- تمام رشته‌های UI خارجی‌سازی شده‌اند:
  - iOS: `Core/MarviL10n.swift` (enum کلید + مپ EN/TR).
  - Android: `l10n/MarviL10n.kt` (enum `Key` + دو مپ `english`/`turkish` + توابع کمکی مثل `categoryLabel`).
- الگوی افزودن رشتهٔ جدید: یک کلید به enum اضافه کن، سپس مقدارش را در هر دو مپ انگلیسی و ترکی بگذار.
- زبان انتخابی کاربر ذخیره می‌شود (snapshot/DataStore) و می‌تواند دستی override شود.

---

## ۱۱. سیستم طراحی (Design System)

- **iOS:** `Core/DesignSystem/` — توکن‌های رنگ (`Colors.swift`)، گرادیان (`Gradients.swift`)، کامپوننت‌ها (`SecretSocietyComponents.swift`, `OfferImagery.swift`, `WorkspaceRolePicker.swift`).
- **Android:** `ui/theme/` (`Colors.kt`, `Gradients.kt`, `Theme.kt`) و `ui/components/MarviComponents.kt` (کامپوننت‌های مشترک: `MarviScreen`, `MarviCard`, `StatusPill`, `PrimaryActionButton`, `MarviTextField`, `EmptyStateView`, ...).
- تم بصری: تیره (dark)، با رنگ برند (Rose)، پنل‌ها و «ambient glow»؛ هدف هماهنگی ظاهر بین iOS و Android.
- مرجع مشترک توکن‌ها: `docs/DESIGN_SYSTEM.md`.

---

## ۱۲. جریان عملیات و انتشار (Ops)

اسکریپت‌های ریشه (در `package.json`) کل چرخهٔ انتشار را خودکار می‌کنند:

| دستور | کار |
|-------|-----|
| `npm run status` | وضعیت git + دیتابیس + iOS + وب |
| `npm run verify` | بررسی‌های پیش از انتشار |
| `npm run sync` | verify → ترکیب/پوش migrations → به‌روزرسانی manifest → commit → push به GitHub |
| `npm run db:push` | فقط اعمال migrations روی Supabase |
| `npm run testflight` | ساخت IPA و آپلود به TestFlight (فقط iOS) |
| `npm run build:android` | ساخت نسخهٔ ریلیز Android |
| `npm run rollback` | راهنمای rollback |
| `npm run release -- <version> "summary"` | ثبت رسمی نسخه در `CHANGELOG.md` |

**نسخه‌بندی:**
- iOS: `CURRENT_PROJECT_VERSION`/`MARKETING_VERSION` در `project.pbxproj` + بخش `components.ios` در `release/manifest.json`.
- Android: `versionCode`/`versionName` در `apps/android/app/build.gradle.kts` + بخش `components.android` در `release/manifest.json`.
- منبع حقیقت نسخه‌ها: `release/manifest.json` (که syncLog و releases را هم نگه می‌دارد).

**قاعده:** بعد از هر تغییرِ کد/SQL باید sync به GitHub انجام شود؛ اگر تغییر روی اپ iOS بود، بیلد به TestFlight هم می‌رود. جزئیات در `docs/OPERATIONS.md`.

---

## ۱۳. نقشهٔ فایل‌های کلیدی

«کجا چه چیزی است» — برای پیدا کردن سریع:

| می‌خواهی... | iOS | Android |
|-------------|-----|---------|
| نقطهٔ ورود اپ | `App/MarviSocietyApp.swift` | `MainActivity.kt` → `ui/MarviApp.kt` |
| state/منطق مرکزی | `App/AppState.swift` | `ui/viewmodel/AppViewModel.kt` |
| قرارداد/لایهٔ API | `Core/Networking/MarviAPI.swift` + `.../SupabaseMarviAPI.swift` | `network/MarviRepository.kt` |
| کلاینت HTTP Supabase | `Core/Networking/Supabase/SupabaseClient.swift` | `network/SupabaseClient.kt` |
| مدل‌های داده | `Core/Models/DomainModels.swift` | `data/Models.kt` |
| زبان (i18n) | `Core/MarviL10n.swift` | `l10n/MarviL10n.kt` |
| صفحهٔ کشف/نقشه | `Features/Discover/*` | `ui/screens/DiscoverScreen.kt`, `MapDiscoverScreen.kt` |
| جزئیات پیشنهاد | `Features/OfferDetail/OfferDetailView.swift` | `ui/screens/DetailScreens.kt` |
| رزروها + چت همکاری | `Features/Bookings/*` | `ui/screens/BookingsScreen.kt`, `DetailScreens.kt` |
| پروفایل | `Features/Profile/*` | `ui/screens/ProfileScreen.kt` |
| استودیوی مکان | `Features/VenueStudio/*` | `ui/screens/AdminScreens.kt` / studio |
| کنسول ادمین | `Features/Admin/*` | `ui/screens/AdminScreens.kt` |
| کامپوننت‌های UI مشترک | `Core/DesignSystem/*` | `ui/components/MarviComponents.kt`, `ui/theme/*` |

بک‌اند: همه چیز زیر `infra/supabase/migrations/`. وب: زیر `apps/web/src/`.

---

## ۱۴. یک جریان کامل از UI تا دیتابیس

مثال: **سازنده یک پیشنهاد از نوع gift را می‌پذیرد** (نشان می‌دهد لایه‌ها چطور به هم وصل‌اند — نسخهٔ Android):

```text
1) UI: OfferDetailScreen → کاربر «Confirm gift» را می‌زند → دیالوگ آدرس ارسال باز می‌شود.
2) UI: با تأیید، viewModel.acceptOffer(offerId, shippingAddress = "...") صدا زده می‌شود.
3) ViewModel (AppViewModel): دروازه‌ها را چک می‌کند (approved بودن، ثبت سوشال)،
   سپس repository.acceptOffer(offerId, AcceptOfferOptions(shippingAddress=...)) را در viewModelScope اجرا می‌کند.
4) Repository (MarviRepository): RPC «accept_offer» را با
   { p_offer_id, p_shipping_address, p_rsvp_guests } از طریق SupabaseClient صدا می‌زند.
5) SupabaseClient (Ktor): POST به /rest/v1/rpc/accept_offer با هدر Bearer JWT.
6) Postgres RPC accept_offer: ظرفیت را چک/کم می‌کند (بدون overbooking)،
   رکورد bookings با stage=confirmed می‌سازد، و RLS مالکیت را تضمین می‌کند.
7) پاسخ برمی‌گردد → repository رزرو را hydrate می‌کند →
   ViewModel لیست bookings را به‌روز می‌کند → UI تب My Events آپدیت می‌شود.
```

معادل iOS دقیقاً همین است با `AppState.accept(offer, options:)` → `MarviAPI.acceptOffer` → `SupabaseMarviAPI` → RPC یکسان.

---

## ۱۵. وضعیت فعلی هر پلتفرم

| پلتفرم | وضعیت |
|--------|-------|
| **iOS (SwiftUI)** | کلاینت اصلی و کامل‌ترین: کشف + نقشه، ۴ مدل همکاری، پذیرش با RSVP/gift، check-in، proof، چت همکاری، انجمن، پروفایل عمیق، استودیوی مکان، کنسول ادمین، strikes. |
| **Android (Compose)** | به پریتی iOS نزدیک شده: کشف + نقشهٔ osmdroid، جزئیات پیشنهاد با شیت‌های RSVP/gift، رزروها + چت همکاری + دعوت‌های در انتظار + ارزیابی مکان، انجمن، پروفایل، استودیو، ادمین. |
| **Web (Next.js)** | سایت مارکتینگ + صفحات حقوقی + حذف حساب + پرتال مکان + کنسول ادمین + مسیرهای API. |
| **Backend (Supabase)** | اسکیمای کامل: ~۳۲ جدول، ۹ enum، ~۹۰ RPC، RLS روی همه، Storage، outbox ایمیل/پوش. |

---

### جمع‌بندی

Marvi Society یک **بازارگاه تهاتری خصوصی creator↔venue** با کنترل کیفیت ادمین است. معماری‌اش **کلاینت‌محور + Supabase به‌عنوان بک‌اند** است: منطق کسب‌وکار در RPCهای Postgres، امنیت با RLS، و دو کلاینت بومی (SwiftUI و Compose) که هر کدام یک لایهٔ state مرکزی (`AppState`/`AppViewModel`) و یک لایهٔ داده (`MarviAPI`/`MarviRepository`) روی یک کلاینت REST سبک دارند. وب برای مارکتینگ، حقوقی و پرتال/ادمین است. کل چرخهٔ انتشار با اسکریپت‌های `npm run ...` خودکار شده و منبع حقیقت نسخه‌ها `release/manifest.json` است.

> برای عمیق‌تر شدن: `docs/PRODUCT.md` (تعریف محصول)، `docs/ARCHITECTURE.md` (طراحی سیستم)، `docs/BACKEND_SCHEMA.md` (اسکیمای دیتابیس)، `docs/OPERATIONS.md` (عملیات)، `docs/DESIGN_SYSTEM.md` (توکن‌های UI).
