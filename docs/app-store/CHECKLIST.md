# App Store Submission Checklist

Complete before submitting **Marvi Society** v1.0.

## Apple Developer Program

- [ ] Enrolled in Apple Developer Program ($99/year)
- [ ] App ID `com.marvisociety.app` registered
- [ ] Sign in with Apple capability enabled for App ID
- [ ] Distribution certificate + App Store provisioning profile

## Backend & website (blockers)

- [ ] Supabase production project live
- [ ] Run SQL: `infra/supabase/fix-user-account.sql` (includes hardening + account fix)
- [ ] Run SQL: `infra/supabase/migrations/20260610000002_delete_own_account.sql`
- [ ] Vercel deploy `apps/web` → `marvisociety.com`
- [ ] Verify live URLs:
  - [ ] https://marvisociety.com/privacy
  - [ ] https://marvisociety.com/terms
  - [ ] https://marvisociety.com/community-guidelines
  - [ ] https://marvisociety.com/delete-account
  - [ ] https://marvisociety.com/contact
- [ ] Supabase Auth SMTP configured (for delete-account OTP emails)
- [ ] `SUPABASE_SERVICE_ROLE_KEY` set on Vercel (delete-account confirm route)

## iOS build

- [ ] `Config/Secrets.xcconfig` with production Supabase URL + anon key
- [ ] App icon `MarviIcon.png` in asset catalog (1024×1024)
- [ ] Archive Release build in Xcode
- [ ] Upload to App Store Connect (Organizer → Distribute)

## App Store Connect metadata

- [ ] Copy from [LISTING.md](LISTING.md): name, subtitle, description, keywords
- [ ] Privacy Policy URL
- [ ] Support URL
- [ ] Screenshots (6.7", 6.5" minimum)
- [ ] App Privacy questionnaire (match PrivacyInfo.xcprivacy)
- [ ] Age rating questionnaire (recommend 17+)
- [ ] Export compliance: **No** non-exempt encryption (HTTPS only)

## Apple review preparation

- [ ] Demo account + invite code in Review Notes
- [ ] Test full flow: sign in → Explore → Accept → Check-in → Proof
- [ ] Test delete account flow end-to-end
- [ ] Confirm 18+ toggle on onboarding
- [ ] Confirm legal links open in Safari

## Post-approval

- [ ] Update `SITE.appStoreUrl` in `apps/web/src/lib/constants.ts`
- [ ] Add App Store badge to marketing site footer
