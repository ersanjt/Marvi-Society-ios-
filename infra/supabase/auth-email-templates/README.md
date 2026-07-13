# Supabase Auth Email Templates — Marvi Society

Paste these into **Supabase Dashboard → Authentication → Email Templates**.

## Critical: Site URL (fixes localhost links)

**Authentication → URL Configuration**

| Field | Value |
|-------|--------|
| **Site URL** | `https://marvisociety.com` |
| **Redirect URLs** | Add all below |

```
https://marvisociety.com/auth/reset-password
https://marvisociety.com/auth/callback
https://marvisociety.com/portal/dashboard
https://marvisociety.com/portal/login
http://localhost:3000/auth/reset-password
http://localhost:3000/auth/callback
```

Without this, password reset emails link to `localhost:3000` and fail on iPhone.

## SMTP (recommended)

**Authentication → SMTP Settings**

- Host: `smtp.resend.com`
- Port: `465`
- User: `resend`
- Password: Resend API key
- Sender: `Marvi Society <hello@marvisociety.com>`

## Templates

### Reset password (Recovery)

- **Subject (TR):** `Marvi Society — şifrenizi sıfırlayın`
- **Body:** paste `recovery-tr.html`

Or English:

- **Subject:** `Marvi Society — reset your password`
- **Body:** paste `recovery-en.html`

### Confirm signup

- **Subject (TR):** `Marvi Society — e-postanızı onaylayın`
- **Body:** paste `confirmation-tr.html`

### Invite user (Auth invite fallback)

Used when Resend is not configured — `send-email` falls back to Supabase Auth invite.

- **Subject (TR):** `Marvi Society — davetlisiniz`
- **Body:** paste `invite-user-tr.html`

Make sure `{{ .Data.invite_code }}` is kept so the code appears in the email.


## iOS app

The app sends `redirect_to: https://marvisociety.com/auth/reset-password` on forgot-password.
Users set a new password on the web page, then sign in again in the app.
