"use client";

import { useMemo, useState } from "react";

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

export function AdminUserDirectory({ initialUsers }: { initialUsers: AdminUser[] }) {
  const [users, setUsers] = useState(initialUsers);
  const [query, setQuery] = useState("");
  const [message, setMessage] = useState("");
  const [selected, setSelected] = useState<AdminUser | null>(null);
  const [notifyTitle, setNotifyTitle] = useState("");
  const [notifyBody, setNotifyBody] = useState("");
  const [emailSubject, setEmailSubject] = useState("");
  const [emailBody, setEmailBody] = useState("");
  const [inviteEmail, setInviteEmail] = useState("");
  const [inviteCode, setInviteCode] = useState("TURGUT");
  const [createEmail, setCreateEmail] = useState("");
  const [createName, setCreateName] = useState("");
  const [createCity, setCreateCity] = useState("istanbul");
  const [createPassword, setCreatePassword] = useState("");

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
      setMessage(json.error ?? "Request failed");
      return false;
    }
    setMessage(json.message ?? "Done");
    await refreshUsers();
    return true;
  }

  return (
    <div className="space-y-6">
      <div className="marvi-card space-y-3 p-5">
        <p className="text-xs font-bold uppercase tracking-widest text-muted">Create account</p>
        <div className="grid gap-3 md:grid-cols-2">
          <input className="marvi-input" placeholder="Email" value={createEmail} onChange={(e) => setCreateEmail(e.target.value)} />
          <input className="marvi-input" placeholder="Full name" value={createName} onChange={(e) => setCreateName(e.target.value)} />
          <input className="marvi-input" placeholder="City" value={createCity} onChange={(e) => setCreateCity(e.target.value)} />
          <input className="marvi-input" placeholder="Password (optional)" value={createPassword} onChange={(e) => setCreatePassword(e.target.value)} />
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
          Create & approve user
        </button>
      </div>

      <div className="marvi-card space-y-3 p-5">
        <p className="text-xs font-bold uppercase tracking-widest text-muted">Send invite email</p>
        <div className="grid gap-3 md:grid-cols-2">
          <input className="marvi-input" placeholder="Email" value={inviteEmail} onChange={(e) => setInviteEmail(e.target.value)} />
          <input className="marvi-input" placeholder="Invite code" value={inviteCode} onChange={(e) => setInviteCode(e.target.value)} />
        </div>
        <button className="marvi-btn-secondary" onClick={() => post("/api/admin/invites", { email: inviteEmail, invite_code: inviteCode })}>
          Send invite
        </button>
      </div>

      <input
        className="marvi-input w-full"
        placeholder="Search users…"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
      />

      {message ? <p className="text-sm font-semibold text-emerald">{message}</p> : null}

      <div className="space-y-3">
        {filtered.map((user) => (
          <button
            key={user.user_id}
            className="marvi-card w-full p-4 text-left transition hover:border-rose/40"
            onClick={() => setSelected(user)}
          >
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="font-semibold text-ink">{user.full_name || user.email || user.user_id.slice(0, 8)}</p>
                <p className="text-sm text-muted">{user.email}</p>
                <p className="mt-1 text-xs text-muted">
                  {user.status} · {user.city || "no city"}
                  {user.last_lat != null ? " · live location" : ""}
                </p>
              </div>
              <span className="text-xs font-bold uppercase text-rose">Manage</span>
            </div>
          </button>
        ))}
      </div>

      {selected ? (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/60 p-4 md:items-center">
          <div className="marvi-card max-h-[85vh] w-full max-w-lg overflow-y-auto p-5">
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="font-serif text-2xl font-bold">{selected.full_name || selected.email}</p>
                <p className="text-sm text-muted">{selected.email}</p>
              </div>
              <button className="text-sm font-semibold text-muted" onClick={() => setSelected(null)}>
                Close
              </button>
            </div>

            <div className="mt-4 flex flex-wrap gap-2">
              <button className="marvi-btn-secondary" onClick={() => post(`/api/admin/users/${selected.user_id}/status`, { status: "approved" })}>
                Approve
              </button>
              <button className="marvi-btn-danger" onClick={() => post(`/api/admin/users/${selected.user_id}/status`, { status: "paused" })}>
                Block
              </button>
            </div>

            <div className="mt-4 space-y-2">
              <input className="marvi-input w-full" placeholder="Notification title" value={notifyTitle} onChange={(e) => setNotifyTitle(e.target.value)} />
              <input className="marvi-input w-full" placeholder="Notification body" value={notifyBody} onChange={(e) => setNotifyBody(e.target.value)} />
              <button
                className="marvi-btn-primary w-full"
                onClick={() =>
                  post(`/api/admin/users/${selected.user_id}/notify`, {
                    title: notifyTitle,
                    body: notifyBody,
                  })
                }
              >
                Send notification + push
              </button>
            </div>

            <div className="mt-4 space-y-2">
              <input className="marvi-input w-full" placeholder="Email subject" value={emailSubject} onChange={(e) => setEmailSubject(e.target.value)} />
              <textarea className="marvi-input min-h-24 w-full" placeholder="Email body" value={emailBody} onChange={(e) => setEmailBody(e.target.value)} />
              <button
                className="marvi-btn-secondary w-full"
                onClick={() =>
                  post(`/api/admin/users/${selected.user_id}/email`, {
                    subject: emailSubject,
                    body: emailBody,
                  })
                }
              >
                Send email
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
