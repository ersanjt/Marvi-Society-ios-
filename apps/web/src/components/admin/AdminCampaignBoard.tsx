"use client";

import { useMemo, useState } from "react";
import { StatusPill, SyncBanner } from "@/components/design/MarviUI";

type CampaignRow = {
  id: string;
  title: string;
  status: string;
  date_label: string | null;
  capacity: number | null;
  remaining_slots: number | null;
  deleted_at: string | null;
  admin_block_reason: string | null;
  venue_profiles?:
    | { venue_name?: string | null; area?: string | null }
    | { venue_name?: string | null; area?: string | null }[]
    | null;
};

function venueMeta(row: CampaignRow) {
  const raw = row.venue_profiles;
  const venue = Array.isArray(raw) ? raw[0] : raw;
  return {
    name: venue?.venue_name ?? "Venue",
    area: venue?.area ?? "",
  };
}

type Filter = "all" | "review" | "live" | "draft" | "completed" | "deleted";

export function AdminCampaignBoard({ initialCampaigns }: { initialCampaigns: CampaignRow[] }) {
  const [campaigns, setCampaigns] = useState(initialCampaigns);
  const [filter, setFilter] = useState<Filter>("all");
  const [message, setMessage] = useState("");
  const [tone, setTone] = useState<"success" | "error">("success");
  const [busyId, setBusyId] = useState<string | null>(null);

  const filtered = useMemo(() => {
    return campaigns.filter((c) => {
      const deleted = !!c.deleted_at;
      if (filter === "deleted") return deleted;
      if (deleted) return false;
      if (filter === "all") return true;
      return c.status === filter;
    });
  }, [campaigns, filter]);

  async function refresh() {
    const response = await fetch("/api/admin/campaigns");
    const json = await response.json();
    if (json.campaigns) setCampaigns(json.campaigns);
  }

  async function run(id: string, body: Record<string, unknown>) {
    setBusyId(id);
    setMessage("");
    const response = await fetch(`/api/admin/campaigns/${id}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    const json = await response.json();
    setBusyId(null);
    if (!response.ok) {
      setTone("error");
      setMessage(json.error ?? "Request failed");
      return;
    }
    setTone("success");
    setMessage(json.message ?? "Done");
    await refresh();
  }

  const filters: Filter[] = ["all", "review", "live", "draft", "completed", "deleted"];

  return (
    <div className="space-y-4">
      {message ? <SyncBanner tone={tone === "error" ? "error" : "success"} message={message} /> : null}

      <div className="flex flex-wrap gap-2">
        {filters.map((item) => (
          <button
            key={item}
            type="button"
            onClick={() => setFilter(item)}
            className={`rounded-full px-3 py-1.5 text-xs font-bold uppercase ${
              filter === item ? "bg-rose text-white" : "bg-panel-elevated text-ink"
            }`}
          >
            {item}
          </button>
        ))}
      </div>

      <div className="space-y-3">
        {filtered.map((campaign) => {
          const venue = venueMeta(campaign);
          const deleted = !!campaign.deleted_at;
          return (
            <div key={campaign.id} className="marvi-card space-y-3 p-4">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <p className="font-semibold text-ink">{campaign.title}</p>
                  <p className="text-sm text-muted">
                    {venue.name}
                    {venue.area ? ` · ${venue.area}` : ""}
                  </p>
                  {campaign.admin_block_reason ? (
                    <p className="mt-1 text-xs font-semibold text-tomato">{campaign.admin_block_reason}</p>
                  ) : null}
                </div>
                <StatusPill
                  label={deleted ? "deleted" : campaign.status}
                  tone={deleted ? "tomato" : campaign.status === "live" ? "emerald" : "aubergine"}
                />
              </div>

              <div className="flex flex-wrap gap-2">
                {deleted ? (
                  <button
                    type="button"
                    className="marvi-btn-secondary"
                    disabled={busyId === campaign.id}
                    onClick={() => run(campaign.id, { action: "restore" })}
                  >
                    Restore
                  </button>
                ) : (
                  <>
                    {(campaign.status === "review" || campaign.status === "draft") && (
                      <button
                        type="button"
                        className="marvi-btn-primary"
                        disabled={busyId === campaign.id}
                        onClick={() =>
                          run(campaign.id, {
                            action: "status",
                            status: "live",
                            reason: "Approved by admin",
                          })
                        }
                      >
                        Approve / Publish
                      </button>
                    )}
                    {campaign.status === "live" && (
                      <button
                        type="button"
                        className="marvi-btn-secondary"
                        disabled={busyId === campaign.id}
                        onClick={() =>
                          run(campaign.id, {
                            action: "status",
                            status: "draft",
                            reason: "Unpublished / blocked by admin",
                          })
                        }
                      >
                        Unpublish / Block
                      </button>
                    )}
                    {campaign.status === "review" && (
                      <button
                        type="button"
                        className="marvi-btn-secondary"
                        disabled={busyId === campaign.id}
                        onClick={() =>
                          run(campaign.id, {
                            action: "status",
                            status: "draft",
                            reason: "Rejected by admin",
                          })
                        }
                      >
                        Reject
                      </button>
                    )}
                    {campaign.status !== "completed" && (
                      <button
                        type="button"
                        className="marvi-btn-secondary"
                        disabled={busyId === campaign.id}
                        onClick={() => run(campaign.id, { action: "status", status: "completed" })}
                      >
                        Complete
                      </button>
                    )}
                    <button
                      type="button"
                      className="text-sm font-bold text-tomato"
                      disabled={busyId === campaign.id}
                      onClick={() => run(campaign.id, { action: "delete", reason: "Deleted by admin" })}
                    >
                      Delete
                    </button>
                  </>
                )}
              </div>
            </div>
          );
        })}
        {filtered.length === 0 ? <p className="text-sm text-muted">No campaigns in this filter.</p> : null}
      </div>
    </div>
  );
}
