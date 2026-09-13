# وضعیت همه بخش‌ها — Marvi Society (۱۳ سپتامبر ۲۰۲۶)

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
| TestFlight | ✅ **1.5.4 (103)** در ریپو |

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
| AAB آماده Play | کد **1.9.13 (59)**؛ AAB روی دیسک هنوز **1.9.7 (53)** |
| آپلود عکس proof + آواتار | ✅ |
| نقشه / push کامل | ✅ کلاینت؛ APNs سرور ⏳ |

### وب
| بخش | وضعیت |
|-----|--------|
| marvisociety.com — marketing | ✅ زنده؛ `/pricing` و `/cookies` در کد ✅ ولی روی WHM هنوز 404 |
| Portal + Admin | ✅ |
| `/auth/callback` + `/auth/reset-password` | ✅ |
| `/auth/ios-callback` | ✅ (deep link به اپ) |
| `/invite` در کد | ✅ — **نیاز به WHM redeploy اگر زنده 404 است** |

### Backend (Supabase)
| بخش | وضعیت |
|-----|--------|
| Offers زنده | ⚠ anon health check خالی است — در Supabase چک شود |
| Resend / send-email | ✅ (آخرین وضعیت ثبت‌شده) |
| Migration head | ✅ `20260831020001_venue_billing_safety_and_trust` (81) |

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
| Deploy وب WHM (`/pricing` + `/cookies`) | SSH key برای `root@92.205.182.143` یا اجرای اسکریپت داخل WHM Terminal |
| Push سرور (APNs) | secrets + `send-push` deploy |
| Auth templates Dashboard | `SUPABASE_ACCESS_TOKEN` + `npm run email:apply-auth-templates` |
| Android map / photo / push کلاینت | ✅ — باقی‌مانده فقط APNs سرور |

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
