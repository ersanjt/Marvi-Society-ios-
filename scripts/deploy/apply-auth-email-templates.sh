#!/usr/bin/env bash
# Apply branded Supabase Auth email templates + Site URL / redirect allow-list.
# Does NOT require Resend.
#
# Usage:
#   SUPABASE_ACCESS_TOKEN=sbp_xxx bash scripts/deploy/apply-auth-email-templates.sh
#
# Create token: https://supabase.com/dashboard/account/tokens
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT_REF="${SUPABASE_PROJECT_REF:-gaswjuvyzliislqrljof}"
TOKEN="${SUPABASE_ACCESS_TOKEN:-}"

if [[ -z "$TOKEN" ]]; then
  echo "ERROR: export SUPABASE_ACCESS_TOKEN=sbp_... first"
  echo "Create at: https://supabase.com/dashboard/account/tokens"
  exit 1
fi

export REPO_ROOT PROJECT_REF SUPABASE_ACCESS_TOKEN="$TOKEN"

python3 <<'PY'
import json, os, urllib.request, urllib.error
from pathlib import Path

repo = Path(os.environ["REPO_ROOT"])
ref = os.environ["PROJECT_REF"]
token = os.environ["SUPABASE_ACCESS_TOKEN"]
tpl = repo / "infra/supabase/auth-email-templates"

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
    "mailer_subjects_confirmation": "Marvi Society — e-postanızı onaylayın",
    "mailer_templates_confirmation_content": read("confirmation-tr.html"),
    "mailer_subjects_recovery": "Marvi Society — şifrenizi sıfırlayın",
    "mailer_templates_recovery_content": read("recovery-tr.html"),
    "mailer_subjects_magic_link": "Marvi Society — bildirim / giriş",
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
        body = json.loads(r.read().decode())
except urllib.error.HTTPError as e:
    print(f"ERROR HTTP {e.code}: {e.read().decode()[:500]}")
    raise SystemExit(1)

print("✓ Auth templates applied")
print(f"  site_url: {body.get('site_url')}")
print(f"  magic subject: {body.get('mailer_subjects_magic_link')}")
print(f"  invite subject: {body.get('mailer_subjects_invite')}")
print(f"  magic has marvi_* fields: {'marvi_email_title' in (body.get('mailer_templates_magic_link_content') or '')}")
print(f"  invite has marvi_* fields: {'marvi_email_title' in (body.get('mailer_templates_invite_content') or '')}")
PY
