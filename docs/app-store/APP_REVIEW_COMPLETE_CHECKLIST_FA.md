# App Review — بررسی کامل قبل از Resubmit (ژوئن 2026)

**Submission ID:** `4e7dbf2a-e85f-42df-95e9-ee6b8551e2ce`  
**رد شده:** بیلد **1.0 (1)** — iPad Air 11-inch (M3), iPadOS 26.5

---

## خلاصه ریجکت اپل

| مشکل | راه‌حل در بیلد 1.0 (6) |
|------|------------------------|
| خطای Sign in with Apple روی iPad | دکمه‌های Apple و Google **مخفی** (`MARVI_*_SIGN_IN_ENABLED = NO`) |
| اکانت دمو / محتوای از پیش پر شده | `review@marvisociety.com` + SQL + یادداشت در Connect |

---

## مشکل ۱ — Sign in with Apple

| بررسی | وضعیت |
|--------|--------|
| `MARVI_APPLE_SIGN_IN_ENABLED = NO` | ✅ |
| `MARVI_GOOGLE_SIGN_IN_ENABLED = NO` | ✅ |
| فقط ورود ایمیل در onboarding | ✅ |
| لایه‌بندی iPad (عرض 520px) | ✅ |
| anchor نمایش Apple (برای آینده) | ✅ در کد |

**مهم:** بیلد **1.0 (5)** هر دو دکمه Apple/Google را نشان می‌دهد — برای App Review **از بیلد (6) استفاده کنید**، نه (5).

---

## مشکل ۲ — اکانت دمو

| بررسی | وضعیت |
|--------|--------|
| ورود `review@marvisociety.com` | ✅ |
| پروفایل approved + admin | ✅ |
| Explore با offer زنده | ✅ |
| booking دمو (Etkinliklerim) | ✅ (بعد از SQL) |
| referral `MARVI-IST` | ✅ |

```bash
cd "/Users/zannanaumova/Downloads/ios 2"
npm run verify:e2e
# باید: ALL E2E CHECKS PASSED
```

اگر booking ✗ بود → Supabase SQL Editor → `infra/supabase/provision-review-account.sql`

---

## بیلد iOS

| مورد | مقدار |
|------|--------|
| نسخه | 1.0 |
| بیلد App Review | **(6)** — email-only |
| IPA | `apps/ios/.build/export/MarviSociety.ipa` |

```bash
bash scripts/app-store/build-ios-release.sh
# Xcode → Organizer → Distribute App → App Store Connect
```

---

## App Store Connect — قبل از Resubmit

### App Review Information

| فیلد | مقدار |
|------|--------|
| Sign-in required | **Yes** |
| Username | `review@marvisociety.com` |
| Password | `MarviReview2026!` |

**Notes + Reply:** کپی از `docs/app-store/CONNECT_PASTE.txt`

### Resubmit (به ترتیب)

1. آپلود و انتخاب بیلد **1.0 (6)** (نه 1 یا 5)
2. App Review Information را پر کنید
3. **Reply to App Review** (متن CONNECT_PASTE)
4. **Resubmit to App Review**

---

## موارد جانبی (خارج از ریجکت مستقیم)

| مورد | وضعیت | اقدام |
|------|--------|--------|
| `/auth/reset-password` روی production | ❌ 404 | Deploy وب: `npm run web:deploy` یا WHM |
| Supabase Site URL | ⚠️ | Dashboard → `https://marvisociety.com` |
| Apple/Google برای کاربران واقعی | بعد از تأیید | `Secrets.xcconfig` → YES + بیلد جدید |

راهنما: `docs/AUTH_EMAIL_FIX_FA.md`, `docs/APPLE_SIGN_IN_SETUP.md`, `docs/GOOGLE_SIGN_IN_SETUP.md`

---

## چک‌لیست نهایی

- [x] کد: Apple + Google خاموش برای App Review
- [x] بیلد شماره 6
- [x] `npm run verify:e2e` — همه ✓
- [ ] آپلود بیلد **1.0 (6)** به Connect
- [ ] App Review Information + Notes
- [ ] Reply به اپل
- [ ] Resubmit
- [ ] (توصیه) Deploy وب + Supabase Site URL

---

## TestFlight (اختیاری قبل از Resubmit)

روی **iPad** تست کنید:
1. ورود با ایمیل review
2. Explore → offer → Accept
3. Etkinliklerim → booking دمو
4. Profile → workspace switcher

بیلد 5 (Apple+Google روشن) را می‌توانید جداگانه برای تست social login آپلود کنید؛ برای **Resubmit** فقط بیلد 6.
