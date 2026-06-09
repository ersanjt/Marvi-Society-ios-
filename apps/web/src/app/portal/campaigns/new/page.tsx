import Link from "next/link";

export const metadata = { title: "New campaign" };

export default function NewCampaignPage() {
  return (
    <div className="mx-auto max-w-2xl px-4 py-12 md:px-6">
      <Link href="/portal/dashboard" className="text-sm font-bold text-emerald">← Back to dashboard</Link>
      <h1 className="mt-4 font-serif text-3xl font-bold">Campaign builder</h1>
      <p className="mt-2 text-sm text-muted">Drafts are sent to admin review before going live.</p>

      <form className="marvi-card mt-8 space-y-4">
        <label className="block text-sm font-semibold">
          Campaign title
          <input className="mt-1 w-full rounded-marvi border border-black/10 px-3 py-2" />
        </label>
        <label className="block text-sm font-semibold">
          Collaboration model
          <select className="mt-1 w-full rounded-marvi border border-black/10 px-3 py-2">
            <option>Invitation</option>
            <option>Event</option>
            <option>Gift</option>
            <option>Instant</option>
          </select>
        </label>
        <label className="block text-sm font-semibold">
          Creator slots
          <input type="number" min={1} className="mt-1 w-full rounded-marvi border border-black/10 px-3 py-2" />
        </label>
        <label className="block text-sm font-semibold">
          Deliverables (one per line)
          <textarea rows={4} className="mt-1 w-full rounded-marvi border border-black/10 px-3 py-2" placeholder="3 Instagram stories&#10;1 Reel" />
        </label>
        <button type="button" className="marvi-btn-primary w-full">
          Submit for review
        </button>
      </form>
    </div>
  );
}
