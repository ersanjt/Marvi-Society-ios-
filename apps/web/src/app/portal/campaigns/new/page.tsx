import { CampaignForm } from "@/components/portal/CampaignForm";
import Link from "next/link";

export const metadata = { title: "New campaign" };

export default function NewCampaignPage() {
  return (
    <div className="mx-auto max-w-2xl px-4 py-12 md:px-6">
      <Link href="/portal/dashboard" className="text-sm font-bold text-emerald">← Back to dashboard</Link>
      <h1 className="mt-4 font-serif text-3xl font-bold">Campaign builder</h1>
      <p className="mt-2 text-sm text-muted">Drafts are sent to admin review before going live.</p>
      <CampaignForm />
    </div>
  );
}
