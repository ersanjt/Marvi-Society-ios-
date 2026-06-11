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

type Props = {
  tasks: AdminTaskRow[];
};

export function AdminTaskQueue({ tasks }: Props) {
  const grouped = useMemo(() => {
    const order = ["creator_application", "campaign_review", "proof_review", "venue_application"];
    return [...tasks].sort((a, b) => order.indexOf(a.type) - order.indexOf(b.type));
  }, [tasks]);

  if (grouped.length === 0) {
    return <div className="marvi-card p-8 text-center text-muted">No open review tasks.</div>;
  }

  return (
    <div className="space-y-3">
      {grouped.map((task) => (
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
      ))}
    </div>
  );
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
      return "Review proof links in the mobile admin console, then approve or issue a strike.";
    default:
      return "";
  }
}
