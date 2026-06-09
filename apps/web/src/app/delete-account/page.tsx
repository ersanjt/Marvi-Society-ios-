import { SectionHeading } from "@/components/marketing/SectionHeading";
import { SITE } from "@/lib/constants";

export const metadata = { title: "Delete account" };

export default function DeleteAccountPage() {
  return (
    <div className="mx-auto max-w-xl px-4 py-16 md:px-6 md:py-24">
      <SectionHeading
        title="Delete your creator account"
        subtitle="Verify your registered email to permanently delete your Marvi Society account."
      />

      <form className="marvi-card mt-10 space-y-4">
        <label className="block text-sm font-semibold">
          Registered email
          <input type="email" required className="mt-1 w-full rounded-marvi border border-black/10 px-3 py-2" placeholder="you@example.com" />
        </label>
        <p className="text-xs text-muted">
          OTP verification will be sent to your email. This action is irreversible. (Connect to Supabase Auth in production.)
        </p>
        <button type="button" className="marvi-btn-primary w-full">
          Send verification code
        </button>
        <p className="text-center text-xs text-muted">
          Need help? <a href={`mailto:${SITE.supportEmail}`} className="font-bold text-emerald">{SITE.supportEmail}</a>
        </p>
      </form>
    </div>
  );
}
