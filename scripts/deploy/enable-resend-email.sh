#!/usr/bin/env bash
# Enable Resend for Marvi Society: secrets, Auth SMTP + templates, flush outbox.
# Usage:
#   RESEND_API_KEY=re_xxx bash scripts/deploy/enable-resend-email.sh
# Optional:
#   SUPABASE_ACCESS_TOKEN=sbp_xxx  (for Auth SMTP + email templates via Management API)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT_REF="${SUPABASE_PROJECT_REF:-gaswjuvyzliislqrljof}"
SB_DIR="$REPO_ROOT/infra/supabase"
SB_URL="https://${PROJECT_REF}.supabase.co"
FROM_EMAIL="${MARVI_FROM_EMAIL:-Marvi Society <hello@marvisociety.com>}"
REPLY_TO="${MARVI_REPLY_TO:-support@marvisociety.com}"
SMTP_ADMIN="${MARVI_SMTP_ADMIN_EMAIL:-hello@marvisociety.com}"

if [[ -z "${RESEND_API_KEY:-}" ]]; then
  echo "ERROR: export RESEND_API_KEY=re_... first"
  echo "Create at: https://resend.com/api-keys"
  exit 1
fi

if [[ ! "$RESEND_API_KEY" =~ ^re_ ]]; then
  echo "ERROR: RESEND_API_KEY should start with re_"
  exit 1
fi

SERVICE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"
if [[ -z "$SERVICE_KEY" && -f "$REPO_ROOT/apps/web/.env.local" ]]; then
  SERVICE_KEY=$(grep '^SUPABASE_SERVICE_ROLE_KEY=' "$REPO_ROOT/apps/web/.env.local" | head -1 | cut -d= -f2- | tr -d '"' | tr -d "'")
fi
if [[ -z "$SERVICE_KEY" ]]; then
  echo "ERROR: SUPABASE_SERVICE_ROLE_KEY missing (apps/web/.env.local or env)"
  exit 1
fi

echo ""
echo "Marvi Society — Enable Resend"
echo "=============================="
echo "Project: $PROJECT_REF"
echo ""

echo "1) Edge Function secrets..."
(
  cd "$SB_DIR"
  npx --yes supabase secrets set \
    "RESEND_API_KEY=${RESEND_API_KEY}" \
    "MARVI_FROM_EMAIL=${FROM_EMAIL}" \
    "MARVI_REPLY_TO=${REPLY_TO}" \
    --project-ref "$PROJECT_REF"
)
echo "   ✓ secrets set"

echo "2) Deploy send-email..."
(
  cd "$SB_DIR"
  npx --yes supabase functions deploy send-email --project-ref "$PROJECT_REF"
)
echo "   ✓ deployed"

echo "3) Health check..."
health=$(curl -sS -m 20 "$SB_URL/functions/v1/send-email")
echo "   $health"
if ! echo "$health" | grep -q '"resendConfigured":true'; then
  echo "ERROR: resendConfigured is still false after deploy"
  exit 1
fi

export REPO_ROOT PROJECT_REF SB_URL SERVICE_KEY RESEND_API_KEY
export SMTP_ADMIN="$SMTP_ADMIN"
export SUPABASE_ACCESS_TOKEN="${SUPABASE_ACCESS_TOKEN:-}"

ACCESS_TOKEN="${SUPABASE_ACCESS_TOKEN:-}"
if [[ -n "$ACCESS_TOKEN" ]]; then
  echo "4) Auth SMTP + branded templates (Management API)..."
  python3 - <<'PY'
import json, os, urllib.request, urllib.error
from pathlib import Path

repo = Path(os.environ["REPO_ROOT"])
tpl = repo / "infra/supabase/auth-email-templates"
token = os.environ["SUPABASE_ACCESS_TOKEN"]
ref = os.environ["PROJECT_REF"]
resend = os.environ["RESEND_API_KEY"]
smtp_admin = os.environ["SMTP_ADMIN"]
from_name = "Marvi Society"

def read(name: str) -> str:
    return (tpl / name).read_text()

payload = {
    "site_url": "https://marvisociety.com",
    "uri_allow_list": ",".join([
        "https://marvisociety.com/auth/reset-password",
        "https://marvisociety.com/auth/callback",
        "https://marvisociety.com/portal/dashboard",
        "https://marvisociety.com/portal/login",
        "http://localhost:3000/auth/reset-password",
        "http://localhost:3000/auth/callback",
    ]),
    "external_email_enabled": True,
    "smtp_admin_email": smtp_admin,
    "smtp_host": "smtp.resend.com",
    "smtp_port": "465",
    "smtp_user": "resend",
    "smtp_pass": resend,
    "smtp_sender_name": from_name,
    "mailer_subjects_confirmation": "Marvi Society — e-postanızı onaylayın",
    "mailer_templates_confirmation_content": read("confirmation-tr.html"),
    "mailer_subjects_recovery": "Marvi Society — şifrenizi sıfırlayın",
    "mailer_templates_recovery_content": read("recovery-tr.html"),
    "mailer_subjects_magic_link": "Marvi Society — giriş bağlantınız",
    "mailer_templates_magic_link_content": read("magic-link-tr.html"),
    "mailer_subjects_invite": "Marvi Society — davetlisiniz",
    "mailer_templates_invite_content": read("invite-user-tr.html"),
}

req = urllib.request.Request(
    f"https://api.supabase.com/v1/projects/{ref}/config/auth",
    data=json.dumps(payload).encode(),
    method="PATCH",
    headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    },
)
try:
    with urllib.request.urlopen(req, timeout=120) as r:
        print(f"   ✓ auth config updated HTTP {r.status}")
except urllib.error.HTTPError as e:
    body = e.read().decode()
    print(f"   ✗ auth config failed HTTP {e.code}: {body[:400]}")
    raise SystemExit(1)
PY
else
  echo "4) Skipping Auth SMTP/templates — set SUPABASE_ACCESS_TOKEN (Dashboard → Account → Access Tokens)"
  echo "   Then re-run this script, or paste templates from infra/supabase/auth-email-templates/"
fi

echo "5) Reset waiting outbox rows + flush..."
python3 - <<'PY'
import json, os, urllib.request, urllib.error, time

url = os.environ["SB_URL"].rstrip("/")
key = os.environ["SERVICE_KEY"]

def call(method, path, body=None, prefer=None):
    data = None if body is None else json.dumps(body).encode()
    headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    }
    if prefer:
        headers["Prefer"] = prefer
    req = urllib.request.Request(url + path, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, r.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()

# Re-queue failed/waiting rows that were blocked on missing Resend
status, body = call(
    "PATCH",
    "/rest/v1/email_outbox?or=(status.eq.pending,status.eq.failed)&error_message=like.*RESEND*",
    {"status": "pending", "error_message": None},
    prefer="return=representation",
)
rows = []
try:
    rows = json.loads(body) if body else []
except Exception:
    rows = []
print(f"   requeued_tagged={len(rows) if isinstance(rows, list) else body[:120]}")

# Also collect all pending ids
status, body = call("GET", "/rest/v1/email_outbox?select=id,template,status&status=eq.pending&order=created_at.asc&limit=100")
pending = json.loads(body)
print(f"   pending_to_flush={len(pending)}")

ok = fail = 0
for row in pending:
    oid = row["id"]
    # Prefer edge function direct send
    st, resp = call("POST", "/functions/v1/send-email", {"outbox_id": oid})
    if st == 200 and '"ok":true' in resp.replace(" ", ""):
        ok += 1
    else:
        # soft fail keep going
        fail += 1
        print(f"   fail {row.get('template')} HTTP {st}: {resp[:160]}")
    time.sleep(0.15)

print(f"   flushed_ok={ok} flushed_fail={fail}")

# Try RPC flush as secondary (service role)
st, resp = call("POST", "/rest/v1/rpc/admin_flush_pending_emails", {"p_limit": 50})
print(f"   rpc_flush HTTP {st}: {resp[:200]}")

st, body = call("GET", "/rest/v1/email_outbox?select=template,status&order=created_at.desc&limit=40")
from collections import Counter
snap = json.loads(body)
print("   snapshot", dict(Counter((r["template"], r["status"]) for r in snap)))
PY

echo ""
echo "✓ Resend enable complete"
echo "  Verify: bash scripts/app-store/verify-emails.sh"
echo ""
