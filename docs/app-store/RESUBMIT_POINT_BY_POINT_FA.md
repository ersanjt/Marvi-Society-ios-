# راهنمای نقطه‌به‌نقطه — رفع ریجکت App Review

**Submission ID:** `4e7dbf2a-e85f-42df-95e9-ee6b8551e2ce`  
**دستگاه تست اپل:** iPad Air 11-inch (M3), iPadOS 26.5

---

## مشکل ۱ — خطای Sign in with Apple (Guideline 2.1a)

| مورد | وضعیت |
|------|--------|
| دکمه Apple در بیلد App Review مخفی است | ✅ `MARVI_APPLE_SIGN_IN_ENABLED = NO` |
| دکمه Google هم مخفی (ایمن برای review) | ✅ `MARVI_GOOGLE_SIGN_IN_ENABLED = NO` |
| ورود با ایمیل اولویت دارد | ✅ |
| لایه‌بندی iPad برای onboarding | ✅ |
| anchor نمایش Apple (برای آینده) | ✅ اصلاح شد |

**علت ریجکت:** اپل روی iPad دکمه Sign in with Apple را زد و خطا دید.

**راه‌حل:** بیلد **1.0 (6)** — فقط ایمیل. Apple/Google بعد از تأیید App Store فعال می‌شوند.

---

## مشکل ۲ — اکانت دمو و محتوای از پیش پر شده (Guideline 2.1a)

| مورد | وضعیت |
|------|--------|
| اکانت `review@marvisociety.com` | ✅ |
| نقش admin + creator + venue | ✅ (با SQL) |
| booking دمو در Etkinliklerim | ✅ (با SQL) |
| یادداشت‌ها در App Review Information | ❌ شما در Connect |

### گام A — Supabase (الزامی، ~۵ دقیقه)

1. [Supabase Dashboard](https://supabase.com/dashboard) → پروژه `marvi-society`
2. **SQL Editor** → New query
3. کل فایل را paste و **Run** کنید:

   `infra/supabase/provision-review-account.sql`

4. تست:

   ```bash
   cd "/Users/zannanaumova/Downloads/ios 2"
   npm run verify:e2e
   ```

   همه چک‌ها باید ✓ باشند (شامل demo booking).

---

## گام B — بیلد 1.0 (6)

```bash
bash scripts/app-store/build-ios-release.sh
```

IPA: `apps/ios/.build/export/MarviSociety.ipa`

1. Xcode → **Window → Organizer**
2. آرشیو جدید → **Distribute App** → App Store Connect
3. منتظر پردازش در TestFlight بمانید

---

## گام C — App Store Connect

1. **App Review Information**
   - Username: `review@marvisociety.com`
   - Password: `MarviReview2026!`
   - Notes: از `docs/app-store/CONNECT_PASTE.txt`

2. بیلد **1.0 (6)** را انتخاب کنید (نه 1 یا 5)

3. **Reply to App Review** → متن دوم در CONNECT_PASTE

4. **Resubmit to App Review**

---

## گام D — Deploy وب (توصیه، نه blocker مستقیم)

```bash
npm run web:deploy
# یا deploy روی WHM
```

سپس Supabase → Authentication → URL Configuration:
- Site URL: `https://marvisociety.com`
- Redirect: `https://marvisociety.com/auth/reset-password`

تست: `npm run verify:auth`

---

## بعد از تأیید App Store

برای فعال‌سازی Apple + Google در نسخه بعدی:

1. `apps/ios/Config/Secrets.xcconfig` → `MARVI_APPLE_SIGN_IN_ENABLED = YES` و `MARVI_GOOGLE_SIGN_IN_ENABLED = YES`
2. Supabase providers را تأیید کنید (`docs/APPLE_SIGN_IN_SETUP.md`, `docs/GOOGLE_SIGN_IN_SETUP.md`)
3. TestFlight روی iPad تست کنید
4. بیلد جدید آپلود کنید
