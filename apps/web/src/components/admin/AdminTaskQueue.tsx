"use client";

import { useMemo, useState } from "react";
import { EmptyState, StatusPill, SyncBanner } from "@/components/design/MarviUI";
import { formatStatusLabel, taskTypeTone } from "@/lib/operational/status";
import { IconShield } from "@/components/design/MarviIcons";
import type { Locale } from "@/lib/i18n/dictionaries";
import type { PortalAdminDict } from "@/lib/i18n/portal-admin";

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
  dict: PortalAdminDict;
  locale: Locale;
};

export function AdminTaskQueue({ tasks, proofBookings = {}, dict, locale }: Props) {
  const [filter, setFilter] = useState<string>("all");
  const q = dict.admin.queue;
  const c = dict.common;

  const tabs = [
    { id: "all", label: q.tabs.all },
    { id: "creator_application", label: q.tabs.creators },
    { id: "venue_application", label: q.tabs.venues },
    { id: "campaign_review", label: q.tabs.campaigns },
    { id: "proof_review", label: q.tabs.proof },
  ] as const;

  const grouped = useMemo(() => {
    const order = ["creator_application", "campaign_review", "proof_review", "venue_application"];
    const sorted = [...tasks].sort((a, b) => order.indexOf(a.type) - order.indexOf(b.type));
    if (filter === "all") return sorted;
    return sorted.filter((t) => t.type === filter);
  }, [tasks, filter]);

  if (tasks.length === 0) {
    return (
      <EmptyState
        icon={<IconShield size={24} />}
        title={q.queueClear}
        body={q.queueClearBody}
      />
    );
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-2">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            type="button"
            onClick={() => setFilter(tab.id)}
            className={
              filter === tab.id
                ? "marvi-pill bg-brand-gradient text-white shadow-rose"
                : "marvi-pill border border-border bg-panel text-graphite"
            }
          >
            {tab.label}
          </button>
        ))}
      </div>

      {grouped.length === 0 ? <p className="text-sm text-muted">{q.noTasksInCategory}</p> : null}

      <div className="space-y-3">
        {grouped.map((task) => {
          const booking = task.subject_id ? proofBookings[task.subject_id] : undefined;
          return (
            <article key={task.id} className="marvi-card">
              <div className="flex flex-wrap items-start justify-between gap-4">
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <StatusPill label={formatStatusLabel(task.type, locale)} tone={taskTypeTone(task.type)} />
                    <StatusPill
                      label={formatStatusLabel(task.priority, locale)}
                      tone={task.priority === "high" ? "tomato" : "muted"}
                    />
                  </div>
                  <h2 className="mt-2 font-bold text-ink">{task.title}</h2>
                  <p className="text-sm text-muted">{task.subtitle}</p>
                  <p className="mt-2 text-xs text-muted">{new Date(task.created_at).toLocaleString(locale === "tr" ? "tr-TR" : "en-GB")}</p>
                  <p className="mt-3 text-sm text-graphite">{hintForType(task.type, q.hints)}</p>

                  {task.type === "proof_review" && booking ? (
                    <div className="mt-4 rounded-marvi border border-border bg-panel-elevated/50 p-4">
                      <p className="marvi-eyebrow">{q.proofLinks}</p>
                      {booking.guest_name ? (
                        <p className="mt-1 text-sm text-muted">
                          {c.guest}: {booking.guest_name}
                        </p>
                      ) : null}
                      {booking.proof_deadline_label ? (
                        <p className="text-sm text-muted">
                          {c.deadline}: {booking.proof_deadline_label}
                        </p>
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
                        <p className="mt-2 text-sm text-muted">{q.noProofLinks}</p>
                      )}
                    </div>
                  ) : null}
                </div>

                <div className="flex w-full flex-col gap-2 sm:w-auto sm:flex-row">
                  <form action={`/api/admin/tasks/${task.id}/approve`} method="post">
                    <button type="submit" className="marvi-btn-primary w-full sm:w-auto">
                      {c.approve}
                    </button>
                  </form>
                  <form action={`/api/admin/tasks/${task.id}/reject`} method="post">
                    <button type="submit" className="marvi-btn-secondary w-full sm:w-auto">
                      {c.reject}
                    </button>
                  </form>
                  {task.type === "proof_review" && task.subject_id ? (
                    <form action={`/api/admin/tasks/${task.id}/strike`} method="post">
                      <input type="hidden" name="booking_id" value={task.subject_id} />
                      <button type="submit" className="marvi-btn-danger w-full sm:w-auto">
                        {q.strike}
                      </button>
                    </form>
                  ) : null}
                </div>
              </div>
            </article>
          );
        })}
      </div>
    </div>
  );
}

function normalizeProofURL(link: string): string {
  const trimmed = link.trim();
  if (trimmed.startsWith("http")) return trimmed;
  return `https://${trimmed}`;
}

function hintForType(type: string, hints: PortalAdminDict["admin"]["queue"]["hints"]): string {
  switch (type) {
    case "creator_application":
      return hints.creator_application;
    case "venue_application":
      return hints.venue_application;
    case "campaign_review":
      return hints.campaign_review;
    case "proof_review":
      return hints.proof_review;
    default:
      return "";
  }
}
