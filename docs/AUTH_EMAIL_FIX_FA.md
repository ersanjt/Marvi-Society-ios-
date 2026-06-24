# رفع خطای فراموشی رمز — iOS و ایمیل

## علت خطا (طبق اسکرین‌شات شما)

| مشکل | علت |
|------|-----|
| لینک ایمیل → `localhost:3000` | **Site URL** در Supabase روی localhost است |
| `ERR_CONNECTION_FAILED` روی iPhone | `localhost` روی گوشی = خود گوشی، نه کامپیوتر شما |
| ایمیل انگلیسی / بدون برند | قالب پیش‌فرض Supabase فعال است |

---

## گام ۱ — Supabase Dashboard (۵ دقیقه، الزامی)

1. [Supabase Dashboard](https://supabase.com/dashboard) → پروژه `gaswjuvyzliislqrljof`
2. **Authentication → URL Configuration**

| فیلد | مقدار |
|------|--------|
| **Site URL** | `https://marvisociety.com` |
| **Redirect URLs** | هر خط را جدا اضافه کنید |

```
https://marvisociety.com/auth/reset-password
https://marvisociety.com/auth/callback
https://marvisociety.com/portal/dashboard
https://marvisociety.com/portal/login
```

3. **Save**

---

## گام ۲ — قالب ایمیل برند Marvi

**Authentication → Email Templates → Reset password**

| فیلد | مقدار |
|------|--------|
| Subject | `Marvi Society — şifrenizi sıfırlayın` |
| Body | محتوای `infra/supabase/auth-email-templates/recovery-tr.html` |

همین کار برای:
- **Confirm signup** → `confirmation-tr.html`
- **Magic link** → `magic-link-tr.html`

راهنمای کامل: `infra/supabase/auth-email-templates/README.md`

---

## گام ۳ — SMTP (اختیاری ولی توصیه‌شده)

**Authentication → SMTP Settings**

- Resend: `smtp.resend.com:465`
- Sender: `Marvi Society <hello@marvisociety.com>`

---

## گام ۴ — Deploy وب

صفحات جدید باید روی production باشند:

- `https://marvisociety.com/auth/reset-password` — تعیین رمز جدید
- `https://marvisociety.com/auth/callback` — تأیید ایمیل / magic link

```bash
cd apps/web && npm run build
# deploy به marvisociety.com
```

تست:

```bash
bash scripts/app-store/verify-auth-urls.sh
```

---

## گام ۵ — بیلد iOS جدید (اختیاری)

اپ حالا `redirect_to` را به `/auth/reset-password` می‌فرستد (نه `/portal/login`).

اگر بیلد 1.0 (3) قبلی را دارید، برای redirect جدید **بیلد 4** بسازید و آپلود کنید.

---

## جریان صحیح برای کاربر

1. اپ iOS → **Şifremi unuttum** (Forgot password)
2. ایمیل Marvi با دکمه **Şifreyi sıfırla**
3. لینک باز می‌شود: `https://marvisociety.com/auth/reset-password`
4. رمز جدید وارد می‌شود
5. اپ را باز کنید → **email + رمز جدید**

---

## نکته

تا **Site URL** در Supabase به `marvisociety.com` تغییر نکند، ایمیل‌ها همچنان `localhost` می‌فرستند — این را فقط از Dashboard می‌توان اصلاح کرد.
