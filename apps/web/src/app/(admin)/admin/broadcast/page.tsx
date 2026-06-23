import { requireAdmin } from "@/lib/auth/admin";
import { redirect } from "next/navigation";
import { AdminBroadcastForm } from "@/components/admin/AdminBroadcastForm";

export const metadata = { title: "Admin broadcast" };

export default async function AdminBroadcastPage() {
  const auth = await requireAdmin();
  if (!auth.ok) {
    redirect("/portal/login?next=/admin/broadcast");
  }

  return (
    <div className="mx-auto max-w-3xl px-4 py-10 md:px-6">
      <div>
        <p className="text-xs font-bold uppercase tracking-widest text-rose">Geo</p>
        <h1 className="font-serif text-3xl font-bold">Area broadcast</h1>
        <p className="mt-1 text-sm text-muted">
          Sends in-app notifications and remote push (when APNs is configured) to approved users near a point.
        </p>
      </div>

      <div className="mt-8">
        <AdminBroadcastForm />
      </div>
    </div>
  );
}
