import { DeleteAccountForm } from "@/components/marketing/DeleteAccountForm";
import { SectionHeading } from "@/components/marketing/SectionHeading";
import { SITE } from "@/lib/constants";

export const metadata = { title: "Delete account" };

export default function DeleteAccountPage() {
  return (
    <div className="mx-auto max-w-xl px-4 py-16 md:px-6 md:py-24">
      <SectionHeading
        title="Manage your account"
        subtitle="Temporarily pause your membership or permanently delete your Marvi Society account."
      />

      <div className="marvi-card mt-10 space-y-3">
        <h2 className="font-serif text-lg font-bold text-ink">Temporarily close account</h2>
        <p className="text-sm text-muted">
          Pauses your membership, stops push notifications, and cancels pending invitations. Your profile and history
          stay saved — reactivate anytime from <strong>Profile → Reactivate account</strong> in the iOS app.
        </p>
        <p className="text-xs text-muted">
          If our team paused your account for policy reasons, contact{" "}
          <a href={`mailto:${SITE.supportEmail}`} className="marvi-link">
            {SITE.supportEmail}
          </a>
          .
        </p>
      </div>

      <SectionHeading
        eyebrow="Permanent"
        title="Delete account forever"
        subtitle="Verify your registered email. This removes all data and cannot be undone."
      />
      <DeleteAccountForm supportEmail={SITE.supportEmail} />
    </div>
  );
}
