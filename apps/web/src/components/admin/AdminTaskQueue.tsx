"use client";

import { useMemo } from "react";

export type AdminTaskRow = {
  id: string;
  type: string;
  title: string;
  subtitle: string;
  priority: string;
  status: string;
  created_at: string;
  subject_id?: string | null;
};

export type ProofBookingRow = {
  id: string;
  proof_links: string[] | null;
  guest_name?: string | null;
  proof_deadline_label?: string | null;
};

type Props = {
  tasks: AdminTaskRow[];
  proofBookings?: Record<string, ProofBookingRow>;
};

export function AdminTaskQueue({ tasks, proofBookings = {} }: Props) {
  const grouped = useMemo(() => {
    const order = ["creator_application", "campaign_review", "proof_review", "venue_application"];
    return [...tasks].sort((a, b) => order.indexOf(a.type) - order.indexOf(b.type));
  }, [tasks]);

  if (grouped.length === 0) {
    return <div className="marvi-card p-8 text-center text-muted">No open review tasks.</div>;
  }

  return (
    <div className="space-y-3">
      {grouped.map((task) => {
        const booking = task.subject_id ? proofBookings[task.subject_id] : undefined;
        return (
          <article key={task.id} className="marvi-card p-5">
            <div className="flex flex-wrap items-start justify-between gap-4">
              <div className="min-w-0 flex-1">
                <p className="text-xs font-bold uppercase text-gold">{task.type.replace(/_/g, " ")}</p>
                <h2 className="font-bold text-ink">{task.title}</h2>
                <p className="text-sm text-muted">{task.subtitle}</p>
                <p className="mt-2 text-xs text-muted">
                  Priority: {task.priority} · {new Date(task.created_at).toLocaleString()}
                </p>
                {task.subject_id ? (
                  <p className="mt-1 break-all font-mono text-xs text-muted">Subject: {task.subject_id}</p>
                ) : null}
                <p className="mt-3 text-sm text-graphite">{hintForType(task.type)}</p>

                {task.type === "proof_review" && booking ? (
                  <div className="mt-4 rounded-xl border border-panel-elevated bg-panel-elevated/40 p-4">
                    <p className="text-xs font-bold uppercase text-emerald">Proof links</p>
                    {booking.guest_name ? (
                      <p className="mt-1 text-sm text-muted">Guest: {booking.guest_name}</p>
                    ) : null}
                    {booking.proof_deadline_label ? (
                      <p className="text-sm text-muted">Deadline: {booking.proof_deadline_label}</p>
                    ) : null}
                    {booking.proof_links?.length ? (
                      <ul className="mt-3 space-y-2">
                        {booking.proof_links.map((link) => (
                          <li key={link}>
                            <a
                              href={normalizeProofURL(link)}
                              target="_blank"
                              rel="noreferrer"
                              className="break-all text-sm font-semibold text-rose hover:underline"
                            >
                              {link}
                            </a>
                          </li>
                        ))}
                      </ul>
                    ) : (
                      <p className="mt-2 text-sm text-muted">No proof links attached yet.</p>
                    )}
                  </div>
                ) : null}
              </div>

              <div className="flex flex-col gap-2 sm:flex-row">
                <form action={`/api/admin/tasks/${task.id}/approve`} method="post">
                  <button type="submit" className="marvi-btn-primary w-full sm:w-auto">
                    Approve
                  </button>
                </form>
                <form action={`/api/admin/tasks/${task.id}/reject`} method="post">
                  <button type="submit" className="marvi-btn-secondary w-full sm:w-auto">
                    Reject
                  </button>
                </form>
                {task.type === "proof_review" && task.subject_id ? (
                  <form action={`/api/admin/tasks/${task.id}/strike`} method="post">
                    <input type="hidden" name="booking_id" value={task.subject_id} />
                    <button type="submit" className="marvi-btn-secondary w-full border-tomato/40 text-tomato sm:w-auto">
                      Issue strike
                    </button>
                  </form>
                ) : null}
              </div>
            </div>
          </article>
        );
      })}
    </div>
  );
}

function normalizeProofURL(link: string): string {
  const trimmed = link.trim();
  if (trimmed.startsWith("http")) return trimmed;
  return `https://${trimmed}`;
}

function hintForType(type: string): string {
  switch (type) {
    case "creator_application":
      return "Approve activates creator membership and Explore access.";
    case "venue_application":
      return "Approve enables venue Studio workspace.";
    case "campaign_review":
      return "Approve publishes this campaign live on Explore.";
    case "proof_review":
      return "Review proof links below, then approve or issue a strike.";
    default:
      return "";
  }
}
