# وضعیت همه بخش‌ها — Marvi Society (ژوئن 2026)

اجرای تست خودکار:

```bash
npm run verify:all
```

---

## ✅ کار می‌کند (تست شده)

### iOS — Creator
| بخش | وضعیت |
|-----|--------|
| ورود ایمیل / ثبت‌نام / فراموشی رمز | ✅ |
| کد دعوت MARVI-IST | ✅ |
| Explore (لیست + فیلتر + نقشه) | ✅ |
| ۴ مدل همکاری (دعوت، رویداد، هدیه، فوری) | ✅ |
| جزئیات offer + پذیرش | ✅ |
| My Events (Etkinliklerim) + check-in + proof | ✅ |
| پروفایل + ویرایش + pause/delete | ✅ |
| Inbox (با refresh دستی) | ✅ |

### iOS — Venue
| بخش | وضعیت |
|-----|--------|
| Venue Studio — چند مکان | ✅ |
| ساخت کمپین + ارسال برای review | ✅ |
| صف review مکان | ✅ |
| Swipe creators (shortlist/pass) | ✅ |

### iOS — Admin
| بخش | وضعیت |
|-----|--------|
| صف تأیید (approve/reject/strike) | ✅ |
| دایرکتوری کاربران | ✅ |
| نقشه کاربران | ✅ |
| Broadcast جغرافیایی | ✅ |

### وب
| بخش | وضعیت |
|-----|--------|
| marvisociety.com — marketing | ✅ |
| Portal (login, dashboard, campaigns, creators, reviews) | ✅ |
| Admin console | ✅ |
| `/auth/callback` + `/auth/reset-password` | ✅ |
| Delete account | ✅ |
| Health API + service role | ✅ |

### Backend (Supabase)
| بخش | وضعیت |
|-----|--------|
| ۹ offer زنده در Explore | ✅ |
| همه RPCهای اصلی | ✅ |
| اکانت review + booking دمو | ✅ |

---

## ⏸ عمداً خاموش (برای App Review)

| بخش | دلیل | فعال‌سازی بعد از تأیید |
|-----|------|------------------------|
| Sign in with Apple | ریجکت اپل روی iPad | `MARVI_APPLE_SIGN_IN_ENABLED = YES` + Supabase Apple |
| Sign in with Google | ایمن‌سازی review | `MARVI_GOOGLE_SIGN_IN_ENABLED = YES` + deploy وب (انجام شد) |

---

## ❌ هنوز deploy / تنظیم نشده

| بخش | مشکل | راه‌حل |
|-----|------|--------|
| **ایمیل تراکنشی** (welcome, OTP) | Edge function `send-email` deploy نشده | `docs/EMAIL_SETUP.md` → Resend + `supabase functions deploy send-email` |
| **Push از سرور** (APNs) | `send-push` deploy نشده | APNs key در Supabase secrets + deploy function |
| **تأیید Instagram/TikTok** | فقط handle در پروفایل | فاز ۲ — OAuth بعدی |
| **Inbox realtime** | فقط pull-to-refresh | فاز ۲ — Supabase Realtime |
| **Android** | نمونه محلی | فاز ۴ |

---

## App Store — الان چه کار کنید

**برای Resubmit (ایمن):**
- بیلد **1.0 (7)** — فقط ایمیل
- اکانت: `review@marvisociety.com` / `MarviReview2026!`
- `docs/app-store/CONNECT_PASTE.txt`

**بعد از تأیید App Store:**
- Apple + Google را روشن کنید
- Edge functions ایمیل/push را deploy کنید

---

## دستورات مفید

```bash
npm run verify:all      # همه تست‌ها
npm run verify:e2e      # اکانت review + وب
npm run verify:auth     # صفحات auth
bash scripts/verify-supabase-rpcs.sh
bash scripts/app-store/build-ios-release.sh
```
