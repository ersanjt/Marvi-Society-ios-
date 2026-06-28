#!/usr/bin/env python3
"""Read or fix the App Store age-rating declaration via the App Store Connect API.

Apple guideline 2.3.6 rejection: the age rating declared "In-App Controls"
(Parental Controls / Age Assurance) but the app has neither. This sets both
to "NONE".

Usage:
  python3 asc_age_rating.py --show        # print current declaration
  python3 asc_age_rating.py --fix         # set parental controls + age assurance to NONE
"""
import argparse
import json
import os
import time
import urllib.request
import urllib.error

import jwt  # pyjwt

KEY_ID = os.environ.get("ASC_KEY_ID", "JT328F7C3Z")
ISSUER_ID = os.environ.get("ASC_ISSUER_ID", "8b84fa76-827a-48b1-bbce-71bdce84ac52")
KEY_PATH = os.environ.get(
    "ASC_KEY_PATH",
    os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8"),
)
BUNDLE_ID = os.environ.get("ASC_BUNDLE_ID", "com.marvisociety.app")
BASE = "https://api.appstoreconnect.apple.com"


def make_token():
    with open(KEY_PATH, "r") as fh:
        private_key = fh.read()
    now = int(time.time())
    payload = {"iss": ISSUER_ID, "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"}
    headers = {"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}
    return jwt.encode(payload, private_key, algorithm="ES256", headers=headers)


def api(method, path, token, body=None):
    url = path if path.startswith("http") else BASE + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        raise SystemExit(f"HTTP {e.code} on {method} {path}\n{detail}")


def get_app_id(token):
    res = api("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}", token)
    if not res.get("data"):
        raise SystemExit(f"No app found for bundleId {BUNDLE_ID}")
    return res["data"][0]["id"]


def get_declarations(token, app_id):
    """Return list of (appInfo_id, declaration_dict)."""
    infos = api("GET", f"/v1/apps/{app_id}/appInfos?limit=10", token).get("data", [])
    out = []
    for info in infos:
        decl = api(
            "GET",
            f"/v1/appInfos/{info['id']}/ageRatingDeclaration",
            token,
        ).get("data")
        out.append((info, decl))
    return out


def show(token):
    app_id = get_app_id(token)
    for info, decl in get_declarations(token, app_id):
        state = info["attributes"].get("appStoreState")
        print(f"\nappInfo {info['id']}  state={state}")
        if not decl:
            print("  (no ageRatingDeclaration)")
            continue
        attrs = decl["attributes"]
        print(f"  declaration id={decl['id']}")
        for k, v in sorted(attrs.items()):
            print(f"    {k}: {v}")


# Disable the In-App Controls signals Apple flagged under guideline 2.3.6.
# These are boolean attributes on the age rating declaration.
FIX_ATTRS = {
    "ageAssurance": False,
    "parentalControls": False,
}


def fix(token):
    app_id = get_app_id(token)
    declarations = get_declarations(token, app_id)
    if not declarations:
        raise SystemExit("No appInfos found.")
    for info, decl in declarations:
        if not decl:
            print(f"appInfo {info['id']}: no declaration, skipping")
            continue
        attrs = decl["attributes"]
        # Only send attributes that actually exist on this declaration.
        body_attrs = {k: v for k, v in FIX_ATTRS.items() if k in attrs}
        if not body_attrs:
            print(f"declaration {decl['id']}: none of {list(FIX_ATTRS)} present; current keys:")
            print("  " + ", ".join(sorted(attrs.keys())))
            continue
        api(
            "PATCH",
            f"/v1/ageRatingDeclarations/{decl['id']}",
            token,
            {"data": {"type": "ageRatingDeclarations", "id": decl["id"], "attributes": body_attrs}},
        )
        print(f"✓ Updated declaration {decl['id']}: {body_attrs}")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--show", action="store_true")
    p.add_argument("--fix", action="store_true")
    args = p.parse_args()

    if not os.path.exists(KEY_PATH):
        raise SystemExit(f"API key not found: {KEY_PATH}")

    token = make_token()
    if args.fix:
        fix(token)
        print("\nAfter fixing, re-show:")
        show(token)
    else:
        show(token)


if __name__ == "__main__":
    main()
