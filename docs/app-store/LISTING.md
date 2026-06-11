# App Store Connect — Listing Copy

Use this content when creating the App Store listing for **Marvi Society** (v1.0).

## App information

| Field | Value |
|-------|-------|
| **Name** | Marvi Society |
| **Subtitle** | Private creator × venue club |
| **Bundle ID** | com.marvisociety.app |
| **Primary category** | Lifestyle |
| **Secondary category** | Social Networking |
| **Content rights** | Does not contain third-party content |
| **Age rating** | 17+ (frequent/intense alcohol or nightlife references; unrestricted web access via legal links) |

## Subtitle (30 chars max)

```
Private creator × venue club
```

## Promotional text (170 chars, updatable without review)

```
Invite-only access to Istanbul's curated creator events. Discover venues, accept invitations, check in, and submit proof — all in one premium app.
```

## Description (English)

```
Marvi Society is Istanbul's private collaboration club for approved creators and verified venues.

Do what you can't — with curated access to real campaigns, not random DMs.

EXPLORE
Browse live venue invitations across dining, nightlife, wellness, beauty, and more. Filter by area, date, and collaboration type. Every campaign lists deliverables, slots, and host notes upfront.

MY EVENTS
Accept invitations, track your timeline, check in with a secure venue code, and submit proof links after your visit. Stay on top of deadlines with clear status badges.

YOUR PROFILE
Manage your creator signals, social handles, and membership status. Sync with your Marvi account and access support or account deletion at any time.

WHO IT'S FOR
• Creators with an invite code and approved membership
• Venue partners with verified profiles (Studio workspace)
• Operators with admin access for quality control

MEMBERSHIP
Marvi Society is invitation-only. Applications are reviewed before invitations go live. You must be 18 or older.

LEGAL
Privacy Policy: https://marvisociety.com/privacy
Terms: https://marvisociety.com/terms
Support: https://marvisociety.com/contact
Delete account: https://marvisociety.com/delete-account
```

## Description (Turkish) — optional secondary localization

```
Marvi Society, onaylı içerik üreticileri ile doğrulanmış mekanları bir araya getiren özel bir iş birliği kulübüdür.

KEŞFET
İstanbul'daki canlı mekan davetlerini inceleyin. Her kampanya teslimatları ve kuralları açıkça listeler.

ETKİNLİKLERİM
Davetleri kabul edin, check-in yapın ve ziyaret sonrası kanıt linklerini gönderin.

ÜYELİK
Davet kodu ve admin onayı gereklidir. 18 yaş ve üzeri.
```

## Keywords (100 chars, comma-separated, no spaces after commas)

```
creator,istanbul,venue,influencer,collab,events,invitation,nightlife,dining,content
```

## Support URL

```
https://marvisociety.com/contact
```

## Marketing URL

```
https://marvisociety.com
```

## Privacy Policy URL

```
https://marvisociety.com/privacy
```

## App Privacy (Nutrition Labels) — declare in App Store Connect

| Data type | Linked to user | Used for tracking | Purpose |
|-----------|---------------|-------------------|---------|
| Email Address | Yes | No | App Functionality |
| Name | Yes | No | App Functionality |
| User ID | Yes | No | App Functionality |
| Photos or Videos | Yes | No | App Functionality |
| Precise Location | Yes | No | App Functionality |

**Tracking:** No  
**Third-party advertising:** No

## Review notes (for Apple)

```
Marvi Society is an invite-only B2B2C marketplace. Test credentials:

Email: [provide test account]
Password: [provide test password]
Invite code: [provide valid referral code from referral_codes table]

The app requires Supabase backend (production). Sign in → Explore shows live venue offers → Accept creates a booking.

Account deletion: Profile → Delete account → opens https://marvisociety.com/delete-account (email OTP verification).

Sign in with Apple is enabled for Release builds. Email/password also supported for review.

No IAP. No ads. 18+ confirmed at onboarding.
```

## Screenshot storyboard (6.7" iPhone)

1. **Explore** — Hero + event list with dark premium UI
2. **Offer detail** — Campaign brief + Accept CTA
3. **My Events** — Active booking with timeline
4. **Check-in / Proof** — Workflow sheet
5. **Profile** — Health ring + legal links section

Capture on iPhone 15 Pro Max simulator or device at 1290×2796.

## Version release notes (1.0)

```
Welcome to Marvi Society 1.0 — the private creator × venue club for Istanbul.

• Browse curated live events
• Accept invitations and manage bookings
• Check in and submit proof in-app
• Full legal, privacy, and account deletion support
```
