import { DeleteAccountForm } from "@/components/marketing/DeleteAccountForm";
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
      <DeleteAccountForm supportEmail={SITE.supportEmail} />
    </div>
  );
}
