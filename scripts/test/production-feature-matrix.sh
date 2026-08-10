#!/bin/bash
# Destructive-safe production smoke test. Creates one isolated account, exercises
# member/business/media flows, then deletes uploaded objects and the account.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CFG="$ROOT/apps/ios/Config/Secrets.xcconfig"
SB_URL=$(sed -n 's/^MARVI_SUPABASE_URL = //p' "$CFG" | head -1 | sed 's|https:/\$()/|https://|' | sed 's|\$()/|/|')
SB_KEY=$(sed -n 's/^MARVI_SUPABASE_ANON_KEY = //p' "$CFG" | head -1)
STAMP=$(date +%s)
EMAIL="${E2E_EMAIL:-marvi-e2e-$STAMP@mailinator.com}"
PASSWORD="${E2E_PASSWORD:-MarviE2E-${STAMP}!Aa}"
PHOTO="$ROOT/apps/ios/MarviSociety/Resources/Assets.xcassets/BrandMark.imageset/BrandMark.png"
TOKEN=""
USER_ID=""
PROFILE_PATH=""
VENUE_PATHS=()
PASS=0
FAIL=0

say_pass() { printf '✓ %-30s %s\n' "$1" "${2:-}"; PASS=$((PASS + 1)); }
say_fail() { printf '✗ %-30s %s\n' "$1" "${2:-}"; FAIL=$((FAIL + 1)); }

json_value() {
  local expression="$1"
  python3 -c "import json,sys; d=json.load(sys.stdin); print($expression)"
}

api() {
  local method="$1" path="$2" body="${3:-}"
  if [[ -n "$body" ]]; then
    curl -fsS -m 30 -X "$method" "$SB_URL$path" \
      -H "apikey: $SB_KEY" -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" -d "$body"
  else
    curl -fsS -m 30 -X "$method" "$SB_URL$path" \
      -H "apikey: $SB_KEY" -H "Authorization: Bearer $TOKEN"
  fi
}

rpc() {
  local body="${2-}"
  [[ -n "$body" ]] || body='{}'
  api POST "/rest/v1/rpc/$1" "$body"
}

cleanup() {
  set +e
  if [[ -n "$TOKEN" ]]; then
    if [[ -n "$PROFILE_PATH" ]]; then
      api DELETE "/storage/v1/object/profile-media" "{\"prefixes\":[\"$PROFILE_PATH\"]}" >/dev/null
    fi
    if [[ ${#VENUE_PATHS[@]} -gt 0 ]]; then
      local joined="" p
      for p in "${VENUE_PATHS[@]}"; do joined="${joined}${joined:+,}\"$p\""; done
      api DELETE "/storage/v1/object/venue-media" "{\"prefixes\":[$joined]}" >/dev/null
    fi
    api POST "/functions/v1/delete-own-account" '{"confirm":"DELETE"}' >/dev/null
  fi
}
trap cleanup EXIT

printf '\nMarvi Society — Production Feature Matrix\n'
printf '=========================================\n'

if [[ -n "${E2E_EMAIL:-}" && -n "${E2E_PASSWORD:-}" ]]; then
  signup=$(curl -sS -m 30 -X POST "$SB_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $SB_KEY" -H "Content-Type: application/json" \
    -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
else
  signup=$(curl -sS -m 30 -X POST "$SB_URL/auth/v1/signup" \
    -H "apikey: $SB_KEY" -H "Content-Type: application/json" \
    -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"data\":{\"full_name\":\"Marvi E2E\",\"city\":\"istanbul\",\"locale\":\"tr\"}}")
fi
TOKEN=$(printf '%s' "$signup" | json_value "d.get('access_token','')")
USER_ID=$(printf '%s' "$signup" | json_value "(d.get('user') or {}).get('id') or d.get('id','')")
if [[ -n "$TOKEN" && -n "$USER_ID" ]]; then
  say_pass "Member sign-up" "active session"
else
  auth_message=$(printf '%s' "$signup" | json_value "d.get('error_description') or d.get('msg') or ('email confirmation required' if (d.get('user') or {}).get('id') else 'no session')")
  say_fail "Member sign-up" "$auth_message"
  exit 1
fi

context=$(rpc fetch_account_context '{}')
status=$(printf '%s' "$context" | json_value "(d[0] if isinstance(d,list) else d).get('status','')")
[[ "$status" == "approved" ]] && say_pass "Immediate membership" "approved" || say_fail "Immediate membership" "$status"

categories=$(api GET '/rest/v1/business_categories?select=slug&is_active=eq.true')
category_count=$(printf '%s' "$categories" | json_value "len(d) if isinstance(d,list) else 0")
[[ "$category_count" -ge 50 ]] && say_pass "Business categories" "$category_count active" || say_fail "Business categories" "$category_count active"

PROFILE_PATH="$USER_ID/avatar/avatar.png"
upload_code=$(curl -sS -m 45 -o /private/tmp/marvi-e2e-upload.json -w '%{http_code}' \
  -X POST "$SB_URL/storage/v1/object/profile-media/$PROFILE_PATH" \
  -H "apikey: $SB_KEY" -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: image/png' -H 'x-upsert: true' --data-binary "@$PHOTO")
[[ "$upload_code" =~ ^20 ]] && say_pass "Profile image upload" "HTTP $upload_code" || say_fail "Profile image upload" "HTTP $upload_code"

upsert_code=$(curl -sS -m 45 -o /private/tmp/marvi-e2e-upsert.json -w '%{http_code}' \
  -X POST "$SB_URL/storage/v1/object/profile-media/$PROFILE_PATH" \
  -H "apikey: $SB_KEY" -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: image/png' -H 'x-upsert: true' --data-binary "@$PHOTO")
[[ "$upsert_code" =~ ^20 ]] && say_pass "Profile image replacement" "HTTP $upsert_code" || say_fail "Profile image replacement" "HTTP $upsert_code"

PUBLIC_PROFILE_URL="$SB_URL/storage/v1/object/public/profile-media/$PROFILE_PATH?v=$STAMP"
public_code=$(curl -sS -m 20 -o /dev/null -w '%{http_code}' "$PUBLIC_PROFILE_URL")
[[ "$public_code" == "200" ]] && say_pass "Public profile image" "HTTP 200" || say_fail "Public profile image" "HTTP $public_code"

patch_code=$(curl -sS -m 30 -o /private/tmp/marvi-e2e-patch.json -w '%{http_code}' \
  -X PATCH "$SB_URL/rest/v1/creator_profiles?user_id=eq.$USER_ID" \
  -H "apikey: $SB_KEY" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"avatar_url\":\"$PUBLIC_PROFILE_URL\",\"cover_url\":\"$PUBLIC_PROFILE_URL\"}")
[[ "$patch_code" =~ ^20 ]] && say_pass "Persist avatar + cover" "HTTP $patch_code" || say_fail "Persist avatar + cover" "HTTP $patch_code"

profile=$(api GET "/rest/v1/creator_profiles?select=avatar_url,cover_url&user_id=eq.$USER_ID")
profile_ok=$(printf '%s' "$profile" | json_value "bool(d and d[0].get('avatar_url') and d[0].get('cover_url'))")
[[ "$profile_ok" == "True" ]] && say_pass "Reload avatar + cover" "persisted" || say_fail "Reload avatar + cover" "missing URL"

showcase=$(curl -sS -m 30 -X POST "$SB_URL/rest/v1/creator_showcase" \
  -H "apikey: $SB_KEY" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -H 'Prefer: return=representation' \
  -d "{\"media_type\":\"image\",\"media_url\":\"$PUBLIC_PROFILE_URL\",\"caption\":\"E2E media\"}")
showcase_id=$(printf '%s' "$showcase" | json_value "d[0].get('id','') if isinstance(d,list) and d else ''")
[[ -n "$showcase_id" ]] && say_pass "Publish profile content" "created" || say_fail "Publish profile content" "insert failed"
if [[ -n "$showcase_id" ]]; then
  delete_showcase=$(rpc delete_showcase_item "{\"p_id\":\"$showcase_id\"}")
  say_pass "Delete profile content" "RPC accepted"
fi

org=$(rpc create_organization_with_brand "{\"p_organization_name\":\"E2E Org $STAMP\",\"p_brand_name\":\"E2E Brand $STAMP\"}")
brand_id=$(printf '%s' "$org" | json_value "d.get('brand_id','')")
[[ -n "$brand_id" ]] && say_pass "Create business + brand" "created" || say_fail "Create business + brand" "missing brand"

venue_id=$(rpc create_establishment_draft "{\"p_brand_id\":\"$brand_id\",\"p_establishment_name\":\"E2E Venue $STAMP\"}" | tr -d '"[:space:]')
[[ "$venue_id" =~ ^[0-9a-f-]{36}$ ]] && say_pass "Create location draft" "$venue_id" || { say_fail "Create location draft" "$venue_id"; exit 1; }

rpc upsert_establishment_details "{\"p_venue_id\":\"$venue_id\",\"p_instagram_handle\":\"marvi_e2e\",\"p_description\":\"Production location workflow verification\",\"p_categories\":[\"coffee-shop\",\"E2E Custom Category\"],\"p_contact_name\":\"Marvi QA\",\"p_contact_phone\":\"+905550000000\",\"p_contact_is_self\":true,\"p_offer_category\":\"dining\"}" >/dev/null
say_pass "Location details + category" "saved"

rpc upsert_establishment_address "{\"p_venue_id\":\"$venue_id\",\"p_is_physical\":true,\"p_country\":\"Türkiye\",\"p_city\":\"İstanbul\",\"p_location_label\":\"Kadıköy\",\"p_address_line1\":\"E2E Test Address\",\"p_address_line2\":\"\",\"p_postal_code\":\"34710\",\"p_lat\":40.9903,\"p_lng\":29.0244}" >/dev/null
say_pass "Location map + address" "saved"

gallery_json=""
for index in logo gallery1 gallery2 gallery3; do
  object_path="$USER_ID/$venue_id/$index-$STAMP.png"
  VENUE_PATHS+=("$object_path")
  code=$(curl -sS -m 45 -o /private/tmp/marvi-e2e-venue-upload.json -w '%{http_code}' \
    -X POST "$SB_URL/storage/v1/object/venue-media/$object_path" \
    -H "apikey: $SB_KEY" -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: image/png' -H 'x-upsert: true' --data-binary "@$PHOTO")
  [[ "$code" =~ ^20 ]] || { say_fail "Location media upload" "$index HTTP $code"; exit 1; }
  url="$SB_URL/storage/v1/object/public/venue-media/$object_path"
  if [[ "$index" == "logo" ]]; then logo_url="$url"; else gallery_json="${gallery_json}${gallery_json:+,}\"$url\""; fi
done
say_pass "Location logo + gallery" "4 uploads"

rpc upsert_establishment_photos "{\"p_venue_id\":\"$venue_id\",\"p_logo_url\":\"$logo_url\",\"p_gallery_urls\":[$gallery_json]}" >/dev/null
say_pass "Persist location media" "logo + 3 gallery"

rpc submit_establishment_for_review "{\"p_venue_id\":\"$venue_id\"}" >/dev/null
say_pass "Submit location review" "admin task created"

my_venues=$(rpc fetch_my_venues '{}')
venue_found=$(printf '%s' "$my_venues" | json_value "any(str(x.get('id','')) == '$venue_id' for x in d)")
[[ "$venue_found" == "True" ]] && say_pass "Reload business location" "found" || say_fail "Reload business location" "missing"

offers=$(api GET '/rest/v1/offers_public?select=id,model&status=eq.live&order=created_at.asc')
offer_count=0
while IFS=$'\t' read -r offer_id offer_model; do
  [[ -n "$offer_id" ]] || continue
  offer_count=$((offer_count + 1))
  case "$offer_model" in
    gift) accept_body="{\"p_offer_id\":\"$offer_id\",\"p_shipping_address\":\"E2E Test Address, Istanbul\",\"p_rsvp_guests\":null}" ;;
    event) accept_body="{\"p_offer_id\":\"$offer_id\",\"p_shipping_address\":null,\"p_rsvp_guests\":2}" ;;
    *) accept_body="{\"p_offer_id\":\"$offer_id\",\"p_shipping_address\":null,\"p_rsvp_guests\":null}" ;;
  esac
  booking_response=$(curl -sS -m 30 -w '\n%{http_code}' -X POST "$SB_URL/rest/v1/rpc/accept_offer" \
    -H "apikey: $SB_KEY" -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -d "$accept_body")
  booking_code=${booking_response##*$'\n'}
  booking=${booking_response%$'\n'*}
  booking_id=$(printf '%s' "$booking" | json_value "d.get('id','')")
  if [[ "$booking_code" =~ ^20 && -n "$booking_id" ]]; then
    say_pass "Collaboration request ($offer_model)" "pending venue"
  else
    booking_error=$(printf '%s' "$booking" | json_value "d.get('message') or d.get('error_description') or d.get('code') or 'no booking'")
    say_fail "Collaboration request ($offer_model)" "HTTP $booking_code: $booking_error"
  fi
  if [[ -n "$booking_id" ]]; then
    if rpc check_in_booking "{\"p_booking_id\":\"$booking_id\",\"p_code\":\"INVALID\"}" >/private/tmp/marvi-e2e-checkin.json 2>&1; then
      say_fail "Reject invalid check-in" "unexpected success"
    else
      say_pass "Reject invalid check-in" "stage/code protected"
    fi
    if rpc submit_proof "{\"p_booking_id\":\"$booking_id\",\"p_links\":[\"$PROFILE_PATH\"]}" >/private/tmp/marvi-e2e-proof.json 2>&1; then
      say_fail "Proof stage gate" "unexpected success"
    else
      say_pass "Proof stage gate" "blocked before visit"
    fi
    rpc cancel_booking "{\"p_booking_id\":\"$booking_id\"}" >/dev/null
    say_pass "Cancel request ($offer_model)" "cancelled"
  fi
done < <(printf '%s' "$offers" | python3 -c 'import json,sys; rows=json.load(sys.stdin); seen=set(); [(print(row.get("id", ""), row.get("model", ""), sep="\t"), seen.add(row.get("model"))) for row in rows if row.get("model") not in seen]')
if [[ "$offer_count" -eq 0 ]]; then
  say_fail "Send collaboration request" "no live offer"
fi

rpc pause_own_account '{}' >/dev/null
say_pass "Pause account" "accepted"
rpc reactivate_own_account '{}' >/dev/null
say_pass "Reactivate account" "accepted"

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
