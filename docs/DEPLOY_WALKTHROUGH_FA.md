# راهنمای Deploy — Marvi Society

راهنمای قدم‌به‌قدم راه‌اندازی **Supabase** + **Vercel** برای Marvi Society.

زمان تقریبی: **۳۰–۴۵ دقیقه**

---

## پیش‌نیاز

- اکانت [GitHub](https://github.com) (repo از قبل push شده)
- اکانت [Supabase](https://supabase.com) (رایگان)
- اکانت [Vercel](https://vercel.com) (رایگان)
- Node.js 20+ روی سیستم شما

---

## بخش ۱ — Supabase (Backend)

### گام ۱: ساخت پروژه

1. برو به [supabase.com/dashboard](https://supabase.com/dashboard)
2. **New project** → نام: `marvi-society`
3. Region: **Central EU (Frankfurt)** — نزدیک‌ترین به Istanbul
4. Database password را یادداشت کن
5. منتظر بمان تا پروژه آماده شود (~۲ دقیقه)

### گام ۲: کپی کلیدهای API

1. **Project Settings** → **API**
2. یادداشت کن:
   - **Project URL** → مثلاً `https://abcdefgh.supabase.co`
   - **anon public** key
   - **service_role** key (محرمانه — فقط سرور)

3. **Project Settings** → **General** → **Reference ID** (مثلاً `abcdefgh`) — برای CLI لازم است

### گام ۳: اجرای Migrationها

**روش A — Supabase CLI (پیشنهادی)**

PowerShell از ریشه repo:

```powershell
cd infra\supabase
npx supabase login
npx supabase link --project-ref YOUR_PROJECT_REF
npx supabase db push
```

**روش B — SQL Editor (بدون CLI)**

1. Supabase Dashboard → **SQL Editor**
2. به ترتیب محتوای این فایل‌ها را Run کن:
   - `migrations/20260609000001_initial_schema.sql`
   - `migrations/20260609000002_rls_policies.sql`
   - `migrations/20260609000003_rpc_functions.sql`
   - `migrations/20260609000004_demo_leads_storage.sql`
   - `migrations/20260609000005_seed_function.sql`

### گام ۴: ساخت کاربر Admin

1. **Authentication** → **Users** → **Add user**
2. Email: ایمیل خودت (مثلاً `you@example.com`)
3. Password: یک رمز قوی
4. UUID کاربر را کپی کن (کلیک روی user → User UID)

### گام ۵: Seed داده دمو

SQL Editor → فایل `infra/supabase/seed-after-deploy.sql` را باز کن، `YOUR_AUTH_USER_UUID` را جایگزین کن، Run:

```sql
SELECT seed_istanbul_demo('paste-your-uuid-here');

UPDATE public.profiles
SET role = 'admin', status = 'approved'
WHERE id = 'paste-your-uuid-here';
```

### گام ۶: Auth تنظیمات

**Authentication** → **URL Configuration**:

| فیلد | مقدار (بعد از Vercel) |
|------|------------------------|
| Site URL | `https://YOUR-APP.vercel.app` |
| Redirect URLs | `https://YOUR-APP.vercel.app/portal/dashboard` |

فعلاً می‌توانی `http://localhost:3000` بگذاری و بعد از Vercel به‌روز کنی.

**Authentication** → **Providers** → **Email**: فعال باشد.

---

## بخش ۲ — تست لوکال با Supabase

```powershell
cd apps\web
copy .env.example .env.local
```

`.env.local` را ویرایش کن:

```env
NEXT_PUBLIC_SUPABASE_URL=https://YOUR_REF.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...
NEXT_PUBLIC_SITE_URL=http://localhost:3000
```

```powershell
npm install
npm run dev
```

تست:

| URL | انتظار |
|-----|--------|
| http://localhost:3000/demo | فرم demo → رکورد در `demo_requests` |
| http://localhost:3000/portal/login | لاگین با email/password |
| http://localhost:3000/portal/dashboard | داده live بعد از login |
| http://localhost:3000/admin | صف admin (بعد از login) |

---

## بخش ۳ — Vercel (Production Web)

### گام ۱: Import پروژه

1. [vercel.com/new](https://vercel.com/new)
2. **Import** از GitHub → `Marvi-Society-ios-`
3. **Root Directory** → Edit → `apps/web`
4. Framework: Next.js (خودکار)

### گام ۲: Environment Variables

قبل از Deploy، **Environment Variables** اضافه کن:

| Name | Value | Environment |
|------|-------|-------------|
| `NEXT_PUBLIC_SUPABASE_URL` | URL پروژه Supabase | Production, Preview |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | anon key | Production, Preview |
| `SUPABASE_SERVICE_ROLE_KEY` | service_role key | Production فقط |
| `NEXT_PUBLIC_SITE_URL` | `https://YOUR-APP.vercel.app` | Production |

### گام ۳: Deploy

**Deploy** → منتظر build (~۲ دقیقه)

URL نهایی: `https://marvi-society-xxx.vercel.app`

### گام ۴: به‌روز Supabase Redirect

برگرد به Supabase → Auth → URL Configuration:

- Site URL = URL Vercel
- Redirect URLs += `/portal/dashboard`

### گام ۵: Deploy با CLI (اختیاری)

```powershell
cd apps\web
npx vercel login
npx vercel link
npx vercel env pull .env.local
npx vercel --prod
```

---

## بخش ۴ — iOS (Supabase mode)

روی Mac:

```bash
cp apps/ios/Config/Secrets.xcconfig.example apps/ios/Config/Secrets.xcconfig
```

```xcconfig
MARVI_SUPABASE_URL = https://YOUR_REF.supabase.co
MARVI_SUPABASE_ANON_KEY = your-anon-key
MARVI_API_MODE = supabase
```

Xcode → Run → onboarding با کد `MARVI-IST`

---

## چک‌لیست نهایی

- [ ] Migrationها اجرا شد
- [ ] Admin user ساخته و seed زده شد
- [ ] `.env.local` لوکال کار می‌کند
- [ ] Vercel deploy موفق
- [ ] Portal login روی production
- [ ] Demo form در `demo_requests` ذخیره می‌شود
- [ ] Supabase Auth redirect URLs به‌روز

---

## عیب‌یابی

| مشکل | راه‌حل |
|------|--------|
| Portal login خطا | Email provider فعال؟ Redirect URL درست؟ |
| Dashboard خالی | `seed_istanbul_demo` با UUID درست؟ |
| Demo form preview mode | `SUPABASE_SERVICE_ROLE_KEY` در Vercel |
| Campaign submit بدون admin task | `SUPABASE_SERVICE_ROLE_KEY` باید در env باشد |
| RLS block | User باید `approved` و role درست باشد |

---

## اسکریپت‌های کمکی

```powershell
# از ریشه repo
.\scripts\deploy\setup-supabase.ps1 -ProjectRef YOUR_REF
.\scripts\deploy\setup-vercel.ps1
```

راهنمای انگلیسی: [DEPLOYMENT.md](./DEPLOYMENT.md)
