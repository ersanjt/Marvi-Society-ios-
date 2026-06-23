# انتشار Marvi Society — قدم‌های نهایی (۱۵–۳۰ دقیقه)

همه‌چیز فنی **آماده** است. فقط App Store Connect نیاز به کلیک تو دارد — من از اینجا نمی‌توانم لاگین Apple کنم.

---

## ✅ انجام‌شده (تأیید شده)

- Production: marvisociety.com · health **ok**
- Supabase: RPCها · review account **approved**
- iOS Archive + IPA: `apps/ios/.build/export/MarviSociety.ipa`
- TestFlight: بیلد 1.0 (1) قبلاً آپلود شده
- Team: GG773SAZP9 · Bundle: com.marvisociety.app

---

## قدم ۱ — TestFlight روی iPhone (۵ دقیقه)

**App Store Connect → Marvi Society → TestFlight → Internal Testing**

1. گروه بساز (مثلاً Team)
2. بیلد **1.0 (1)** را Add کن
3. Export Compliance → **No encryption**
4. Testers → Apple ID خودت را اضافه کن
5. iPhone: اپ **TestFlight** → Install

---

## قدم ۲ — اسکرین‌شات (۱۰ دقیقه)

Xcode → Simulator → **iPhone 15 Pro Max** → اپ را باز کن → **Cmd+S**

۵ تصویر:
1. Explore
2. Offer detail
3. My Events
4. Check-in / Proof
5. Profile

اندازه: **1290 × 2796** (6.7")

---

## قدم ۳ — App Store Connect Submit (۱۵ دقیقه)

**Apps → Marvi Society → Distribution → iOS App → 1.0**

### Metadata (کپی از `docs/app-store/LISTING.md`)

| فیلد | مقدار |
|------|--------|
| Name | Marvi Society |
| Subtitle | Private creator × venue club |
| Category | Lifestyle |
| Privacy URL | https://marvisociety.com/privacy |
| Support URL | https://marvisociety.com/contact |
| Keywords | creator,istanbul,venue,influencer,collab,events |

### Build
- Select **1.0 (1)**
- Export compliance: **No**

### App Privacy
Email, Name, User ID, Photos, Location — **Not for tracking**

### Age Rating
**17+**

### Review Notes
```
Email: review@marvisociety.com
Password: MarviReview2026!
Invite code: MARVI-IST

Sign in → Explore → Accept an offer.
Delete account: Profile → Delete Account.
No IAP. No ads. 18+ at onboarding.
```

### Availability
**All countries** (جهانی)

### Submit
**Add for Review** → **Submit to App Review**

---

## قدم ۴ — SMTP (قبل از review — ضد رد)

**Supabase → Authentication → SMTP**

| Host | mail.marvisociety.com |
| Port | 465 |
| User | review@marvisociety.com |
| Password | رمز cPanel |

تست: https://marvisociety.com/delete-account

---

## اگر IPA جدید لازم بود

```bash
bash scripts/ios/export-testflight.sh
# سپس Transporter app → drag MarviSociety.ipa
```

یا Xcode → Organizer → Distribute App

---

## بعد از تأیید Apple

1. لینک App Store را از Connect کپی کن
2. `apps/web/src/lib/constants.ts` → `appStoreUrl` آپدیت
3. WHM: `bash scripts/deploy/whm-fix-all.sh`

---

**زمان review Apple:** معمولاً ۲۴–۴۸ ساعت.
