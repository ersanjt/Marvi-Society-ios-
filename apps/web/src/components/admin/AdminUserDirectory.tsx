"use client";

import { useMemo, useState } from "react";
import { AvatarRing, StatusPill, SyncBanner } from "@/components/design/MarviUI";
import { formatStatusLabel, membershipStatusTone } from "@/lib/operational/status";
import type { Locale } from "@/lib/i18n/dictionaries";
import type { PortalAdminDict } from "@/lib/i18n/portal-admin";

type AdminUser = {
  user_id: string;
  email: string | null;
  role: string | null;
  status: string | null;
  full_name: string | null;
  instagram_handle: string | null;
  city: string | null;
  strike_count: number | null;
  booking_count: number | null;
  last_lat: number | null;
  last_lng: number | null;
};

function initials(user: AdminUser): string {
  const name = user.full_name || user.email || "U";
  return name
    .split(/\s+/)
    .map((p) => p[0])
    .join("")
    .slice(0, 2);
}

export function AdminUserDirectory({
  initialUsers,
  dict,
  locale,
}: {
  initialUsers: AdminUser[];
  dict: PortalAdminDict;
  locale: Locale;
}) {
  const [users, setUsers] = useState(initialUsers);
  const [query, setQuery] = useState("");
  const [message, setMessage] = useState("");
  const [messageTone, setMessageTone] = useState<"success" | "error">("success");
  const [selected, setSelected] = useState<AdminUser | null>(null);
  const [notifyTitle, setNotifyTitle] = useState("");
  const [notifyBody, setNotifyBody] = useState("");
  const [emailSubject, setEmailSubject] = useState("");
  const [emailBody, setEmailBody] = useState("");
  const [inviteEmail, setInviteEmail] = useState("");
  const [inviteCode, setInviteCode] = useState("MARVI-IST");
  const [createEmail, setCreateEmail] = useState("");
  const [createName, setCreateName] = useState("");
  const [createCity, setCreateCity] = useState("istanbul");
  const [createPassword, setCreatePassword] = useState("");

  const u = dict.admin.users;
  const c = dict.common;

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return users;
    return users.filter((user) =>
      [user.email, user.full_name, user.instagram_handle, user.city]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes(q))
    );
  }, [query, users]);

  async function refreshUsers() {
    const response = await fetch("/api/admin/users");
    const json = await response.json();
    if (json.users) setUsers(json.users);
  }

  async function post(path: string, body: Record<string, unknown>) {
    setMessage("");
    const response = await fetch(path, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    const json = await response.json();
    if (!response.ok) {
      setMessageTone("error");
      setMessage(json.error ?? c.requestFailed);
      return false;
    }
    setMessageTone("success");
    setMessage(json.message ?? c.done);
    await refreshUsers();
    return true;
  }

  return (
    <div className="space-y-6">
      {message ? <SyncBanner tone={messageTone === "error" ? "error" : "success"} message={message} /> : null}

      <div className="marvi-card space-y-4">
        <p className="marvi-eyebrow">{u.provision}</p>
        <p className="text-sm font-bold text-ink">{u.createApprove}</p>
        <div className="grid gap-3 md:grid-cols-2">
          <input className="marvi-input" placeholder={c.email} value={createEmail} onChange={(e) => setCreateEmail(e.target.value)} />
          <input className="marvi-input" placeholder={u.fullName} value={createName} onChange={(e) => setCreateName(e.target.value)} />
          <input className="marvi-input" placeholder={u.city} value={createCity} onChange={(e) => setCreateCity(e.target.value)} />
          <input className="marvi-input" placeholder={u.passwordOptional} value={createPassword} onChange={(e) => setCreatePassword(e.target.value)} />
        </div>
        <button
          className="marvi-btn-primary"
          onClick={() =>
            post("/api/admin/provision", {
              email: createEmail,
              full_name: createName,
              city: createCity,
              password: createPassword || undefined,
            })
          }
        >
          {u.createApprove}
        </button>
      </div>

      <div className="marvi-card space-y-4">
        <p className="marvi-eyebrow">{u.invites}</p>
        <div className="grid gap-3 md:grid-cols-2">
          <input className="marvi-input" placeholder={c.email} value={inviteEmail} onChange={(e) => setInviteEmail(e.target.value)} />
          <input className="marvi-input" placeholder={u.inviteCode} value={inviteCode} onChange={(e) => setInviteCode(e.target.value)} />
        </div>
        <button className="marvi-btn-secondary" onClick={() => post("/api/admin/invites", { email: inviteEmail, invite_code: inviteCode })}>
          {u.sendInvite}
        </button>
      </div>

      <input
        className="marvi-input w-full"
        placeholder={u.searchPlaceholder}
        value={query}
        onChange={(e) => setQuery(e.target.value)}
      />

      <div className="space-y-2">
        {filtered.map((user) => (
          <button
            key={user.user_id}
            type="button"
            className="marvi-card flex w-full items-center gap-4 p-4 text-left transition hover:border-rose/30"
            onClick={() => setSelected(user)}
          >
            <AvatarRing initials={initials(user)} size={48} />
            <div className="min-w-0 flex-1">
              <p className="truncate font-semibold text-ink">{user.full_name || user.email || user.user_id.slice(0, 8)}</p>
              <p className="truncate text-sm text-muted">{user.email}</p>
              <div className="mt-2 flex flex-wrap gap-2">
                <StatusPill label={formatStatusLabel(user.status ?? "unknown", locale)} tone={membershipStatusTone(user.status)} />
                {user.city ? <StatusPill label={user.city} tone="muted" /> : null}
                {user.last_lat != null ? <StatusPill label={u.liveLocation} tone="blue" /> : null}
              </div>
            </div>
            <span className="text-xs font-bold uppercase text-rose">{u.manage}</span>
          </button>
        ))}
      </div>

      {selected ? (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/70 p-4 backdrop-blur-sm md:items-center">
          <div className="marvi-card max-h-[85vh] w-full max-w-lg overflow-y-auto p-5">
            <div className="flex items-start gap-4">
              <AvatarRing initials={initials(selected)} size={56} />
              <div className="min-w-0 flex-1">
                <p className="font-serif text-2xl font-bold text-ink">{selected.full_name || selected.email}</p>
                <p className="text-sm text-muted">{selected.email}</p>
                <div className="mt-2 flex flex-wrap gap-2">
                  <StatusPill label={formatStatusLabel(selected.status ?? "unknown", locale)} tone={membershipStatusTone(selected.status)} />
                  {selected.role ? <StatusPill label={selected.role} tone="aubergine" /> : null}
                </div>
              </div>
              <button type="button" className="text-sm font-semibold text-muted" onClick={() => setSelected(null)}>
                {c.close}
              </button>
            </div>

            <div className="mt-5 flex flex-wrap gap-2">
              <button className="marvi-btn-secondary" onClick={() => post(`/api/admin/users/${selected.user_id}/status`, { status: "approved" })}>
                {c.approve}
              </button>
              <button className="marvi-btn-danger" onClick={() => post(`/api/admin/users/${selected.user_id}/status`, { status: "paused" })}>
                {c.block}
              </button>
            </div>

            <div className="mt-5 space-y-2 border-t border-border pt-5">
              <p className="marvi-eyebrow">{u.pushNotification}</p>
              <input className="marvi-input w-full" placeholder={u.titlePlaceholder} value={notifyTitle} onChange={(e) => setNotifyTitle(e.target.value)} />
              <input className="marvi-input w-full" placeholder={u.bodyPlaceholder} value={notifyBody} onChange={(e) => setNotifyBody(e.target.value)} />
              <button
                className="marvi-btn-primary w-full"
                onClick={() =>
                  post(`/api/admin/users/${selected.user_id}/notify`, {
                    title: notifyTitle,
                    body: notifyBody,
                  })
                }
              >
                {u.sendNotificationPush}
              </button>
            </div>

            <div className="mt-5 space-y-2 border-t border-border pt-5">
              <p className="marvi-eyebrow">{u.emailSection}</p>
              <input className="marvi-input w-full" placeholder={u.subject} value={emailSubject} onChange={(e) => setEmailSubject(e.target.value)} />
              <textarea className="marvi-input min-h-24 w-full" placeholder={u.bodyPlaceholder} value={emailBody} onChange={(e) => setEmailBody(e.target.value)} />
              <button
                className="marvi-btn-secondary w-full"
                onClick={() =>
                  post(`/api/admin/users/${selected.user_id}/email`, {
                    subject: emailSubject,
                    body: emailBody,
                  })
                }
              >
                {u.sendEmail}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
