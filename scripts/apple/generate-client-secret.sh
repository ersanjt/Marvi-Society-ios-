#!/usr/bin/env bash
# Generate Apple Sign in with Apple client secret (JWT) for Supabase.
# Usage:
#   ./scripts/apple/generate-client-secret.sh \
#     --p8 ~/Downloads/AuthKey_J79M28T33W.p8 \
#     --key-id J79M28T33W \
#     --team-id GG773SAZP9 \
#     --client-id com.marvisociety.app.auth
#
# Paste the output into Supabase → Authentication → Sign In / Providers → Apple → Secret Key.
# Secret expires in ~180 days; regenerate before expiry.

set -euo pipefail

P8=""
KEY_ID=""
TEAM_ID=""
CLIENT_ID="com.marvisociety.app.auth"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --p8) P8="$2"; shift 2 ;;
    --key-id) KEY_ID="$2"; shift 2 ;;
    --team-id) TEAM_ID="$2"; shift 2 ;;
    --client-id) CLIENT_ID="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

[[ -f "$P8" ]] || { echo "Missing --p8 path to .p8 file" >&2; exit 1; }
[[ -n "$KEY_ID" ]] || { echo "Missing --key-id" >&2; exit 1; }
[[ -n "$TEAM_ID" ]] || { echo "Missing --team-id" >&2; exit 1; }

P8="$P8" KEY_ID="$KEY_ID" TEAM_ID="$TEAM_ID" CLIENT_ID="$CLIENT_ID" node <<'NODE'
const fs = require('fs');
const crypto = require('crypto');

const privateKey = fs.readFileSync(process.env.P8, 'utf8');
const keyId = process.env.KEY_ID;
const teamId = process.env.TEAM_ID;
const clientId = process.env.CLIENT_ID;

function b64url(input) {
  return Buffer.from(input).toString('base64url');
}

const header = { alg: 'ES256', kid: keyId };
const now = Math.floor(Date.now() / 1000);
const payload = {
  iss: teamId,
  iat: now,
  exp: now + 86400 * 180,
  aud: 'https://appleid.apple.com',
  sub: clientId,
};

const encodedHeader = b64url(JSON.stringify(header));
const encodedPayload = b64url(JSON.stringify(payload));
const data = `${encodedHeader}.${encodedPayload}`;
const sign = crypto.createSign('SHA256');
sign.update(data);
sign.end();
const signature = sign.sign({ key: privateKey, dsaEncoding: 'ieee-p1363' });
console.log(`${data}.${b64url(signature)}`);
NODE
