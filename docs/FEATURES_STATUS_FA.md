# وضعیت همه بخش‌ها — Marvi Society (ژوئیه ۲۰۲۶)

اجرای تست خودکار:

```bash
npm run verify:all
```

---

## ✅ کار می‌کند (تست شده / آنلاین)

### iOS — Creator
| بخش | وضعیت |
|-----|--------|
| ورود ایمیل / ثبت‌نام / فراموشی رمز | ✅ |
| Apple + Google Sign-In | ✅ (در Secrets روشن) |
| Explore (لیست + فیلتر + نقشه) | ✅ |
| ۴ مدل همکاری (دعوت، رویداد، هدیه، فوری) | ✅ |
| جزئیات offer + پذیرش | ✅ |
| My Events + check-in + proof | ✅ |
| Community (فید / اعضا / پیام) | ✅ (SQL UNION فیکس شد) |
| پروفایل + ویرایش + pause/delete | ✅ |
| تأیید ادمین (hard gate) | ✅ |
| Instagram یا TikTok + DM verify اختیاری | ✅ |
| Inbox | ✅ |
| TestFlight | ✅ **1.4.7 (44)** |

### iOS — Venue / Admin
| بخش | وضعیت |
|-----|--------|
| Venue Studio | ✅ |
| Admin queue + approve/reject | ✅ |

### Android
| بخش | وضعیت |
|-----|--------|
| Compose shell + Supabase | ✅ |
| Onboarding + gates (admin / social) | ✅ |
| Google Sign-In (Custom Tabs + PKCE) | ✅ |
| Discover / Bookings / Community / Profile | ✅ |
| AAB آماده Play | ✅ **1.4.8 (39)** در `release/google-play/` |
| آپلود عکس proof + آواتار | ✅ |
| نقشه / push کامل | ⏳ parity بعدی |

### وب
| بخش | وضعیت |
|-----|--------|
| marvisociety.com — marketing | ✅ |
| Portal + Admin | ✅ |
| `/auth/callback` + `/auth/reset-password` | ✅ |
| `/auth/ios-callback` | ✅ (deep link به اپ) |
| `/invite` در کد | ✅ — **نیاز به WHM redeploy اگر زنده 404 است** |

### Backend (Supabase)
| بخش | وضعیت |
|-----|--------|
| Offers زنده | ✅ |
| Resend / send-email | ✅ (`resendConfigured: true`) |
| Migration head | ✅ `20260630000024_soften_social_verify_accept_gate` |

---

## مدل دسترسی (به‌روز)

1. ثبت‌نام (ایمیل / Apple / Google)  
2. Instagram **یا** TikTok  
3. تأیید ادمین (قفل اپ)  
4. استفاده از سرویس‌ها  
5. DM verify سوشال = توصیه / سلامت پروفایل (برای Accept اجباری نیست)

کدهای دعوت = ابزار رشد ادمین؛ گیت سخت عضویت نیستند.

---

## ⏳ باقی‌مانده

| بخش | راه‌حل |
|-----|--------|
| آپلود AAB به Play | دستی در Console یا `play-service-account.json` + `npm run publish:android` |
| Deploy وب WHM (`/invite`) | `npm run web:deploy` روی سرور |
| Push سرور (APNs) | secrets + `send-push` deploy |
| Auth templates Dashboard | `SUPABASE_ACCESS_TOKEN` + `npm run email:apply-auth-templates` |
| Android map / photo / push | parity فاز بعد |

---

## دستورات مفید

```bash
npm run status
npm run verify:all
npm run testflight
npm run build:android && npm run package:android
npm run web:deploy
npm run publish:android   # نیاز به play-service-account.json
```
