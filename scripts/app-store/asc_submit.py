#!/usr/bin/env python3
"""Submit the latest build to App Review via the App Store Connect API.

Usage:
  python3 asc_submit.py --status          # read-only: show app/version/build state
  python3 asc_submit.py --build 13         # attach build 1.0(13) + submit for review
  python3 asc_submit.py --build 13 --wait  # poll until build is processed, then submit

Auth comes from env or defaults:
  ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH
"""
import argparse
import json
import os
import sys
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
MARKETING_VERSION = os.environ.get("ASC_MARKETING_VERSION", "1.0")
BASE = "https://api.appstoreconnect.apple.com"

EDITABLE_STATES = {
    "PREPARE_FOR_SUBMISSION",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "METADATA_REJECTED",
    "INVALID_BINARY",
}


def make_token() -> str:
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


def get_app(token: str) -> dict:
    res = api("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}", token)
    if not res.get("data"):
        raise SystemExit(f"No app found for bundleId {BUNDLE_ID}")
    return res["data"][0]


def get_versions(token: str, app_id: str) -> list:
    res = api(
        "GET",
        f"/v1/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=10",
        token,
    )
    return res.get("data", [])


def find_build(token, app_id, build_version):
    res = api(
        "GET",
        f"/v1/builds?filter[app]={app_id}&filter[version]={build_version}"
        f"&filter[preReleaseVersion.version]={MARKETING_VERSION}&limit=5",
        token,
    )
    data = res.get("data", [])
    return data[0] if data else None


def existing_submissions(token: str, app_id: str) -> list:
    res = api(
        "GET",
        f"/v1/reviewSubmissions?filter[app]={app_id}&filter[state]=READY_FOR_REVIEW,WAITING_FOR_REVIEW,IN_REVIEW,UNRESOLVED_ISSUES&limit=10",
        token,
    )
    return res.get("data", [])


def cancel_submission(token, sub_id):
    """Cancel an in-flight review submission so the version becomes editable."""
    api(
        "PATCH",
        f"/v1/reviewSubmissions/{sub_id}",
        token,
        {"data": {"type": "reviewSubmissions", "id": sub_id, "attributes": {"canceled": True}}},
    )
    print(f"✓ Canceled in-flight submission {sub_id}")
    time.sleep(6)


def show_status(token: str):
    app = get_app(token)
    print(f"App: {app['attributes'].get('name')}  id={app['id']}  bundle={app['attributes'].get('bundleId')}")
    print("\nApp Store Versions (IOS):")
    for v in get_versions(token, app["id"]):
        a = v["attributes"]
        print(f"  - {a.get('versionString')}  state={a.get('appStoreState')}  id={v['id']}")
    print("\nBuilds (1.0):")
    res = api(
        "GET",
        f"/v1/builds?filter[app]={app['id']}&filter[preReleaseVersion.version]={MARKETING_VERSION}&limit=10&sort=-version",
        token,
    )
    for b in res.get("data", []):
        a = b["attributes"]
        print(f"  - build {a.get('version')}  processing={a.get('processingState')}  expired={a.get('expired')}  id={b['id']}")
    print("\nOpen review submissions:")
    subs = existing_submissions(token, app["id"])
    if not subs:
        print("  (none)")
    for s in subs:
        print(f"  - state={s['attributes'].get('state')}  id={s['id']}")


def submit(token: str, build_version: str, wait: bool):
    app = get_app(token)
    app_id = app["id"]

    # 0. If a previous submission is in-flight, cancel it so we can swap the build.
    for s in existing_submissions(token, app_id):
        state = s["attributes"].get("state")
        if state in {"WAITING_FOR_REVIEW", "READY_FOR_REVIEW"}:
            print(f"→ Existing submission state={state}; canceling to swap in build {build_version}")
            cancel_submission(token, s["id"])

    # 1. Resolve an editable version
    version = None
    for _ in range(6):
        versions = get_versions(token, app_id)
        for v in versions:
            if v["attributes"].get("appStoreState") in EDITABLE_STATES:
                version = v
                break
        if version:
            break
        time.sleep(10)
    if version is None:
        raise SystemExit(
            "No editable app store version found. States: "
            + ", ".join(v["attributes"].get("appStoreState", "?") for v in versions)
            + "\nOpen App Store Connect and make sure version 1.0 is in 'Prepare for Submission'."
        )
    version_id = version["id"]
    print(f"→ Editable version {version['attributes'].get('versionString')} (state={version['attributes'].get('appStoreState')}) id={version_id}")

    # 2. Find + wait for the build
    deadline = time.time() + (30 * 60 if wait else 0)
    build = None
    while True:
        build = find_build(token, app_id, build_version)
        state = build["attributes"].get("processingState") if build else None
        if build and state == "VALID":
            print(f"✓ Build 1.0({build_version}) is processed (VALID) id={build['id']}")
            break
        print(f"… build 1.0({build_version}) state={state or 'NOT FOUND'} (waiting={wait})")
        if not wait or time.time() > deadline:
            if not build:
                raise SystemExit(f"Build 1.0({build_version}) not found yet. Re-run with --wait once it appears.")
            if state != "VALID":
                raise SystemExit(f"Build not ready (state={state}). Re-run with --wait.")
        time.sleep(30)

    # 3. Attach build to the version
    api(
        "PATCH",
        f"/v1/appStoreVersions/{version_id}",
        token,
        {
            "data": {
                "type": "appStoreVersions",
                "id": version_id,
                "relationships": {"build": {"data": {"type": "builds", "id": build["id"]}}},
            }
        },
    )
    print("✓ Build attached to version")

    # 4. Reuse or create a review submission
    subs = existing_submissions(token, app_id)
    sub_id = None
    for s in subs:
        if s["attributes"].get("state") in {"READY_FOR_REVIEW", "UNRESOLVED_ISSUES"}:
            sub_id = s["id"]
            print(f"→ Reusing open review submission {sub_id}")
            break
    if sub_id is None:
        res = api(
            "POST",
            "/v1/reviewSubmissions",
            token,
            {
                "data": {
                    "type": "reviewSubmissions",
                    "attributes": {"platform": "IOS"},
                    "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                }
            },
        )
        sub_id = res["data"]["id"]
        print(f"✓ Created review submission {sub_id}")

    # 5. Add the version as an item (ignore if already present)
    try:
        api(
            "POST",
            "/v1/reviewSubmissionItems",
            token,
            {
                "data": {
                    "type": "reviewSubmissionItems",
                    "relationships": {
                        "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub_id}},
                        "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
                    },
                }
            },
        )
        print("✓ Version added to submission")
    except SystemExit as e:
        if "409" in str(e) or "DUPLICATE" in str(e):
            print("→ Version already in submission (ok)")
        else:
            raise

    # 6. Submit
    api(
        "PATCH",
        f"/v1/reviewSubmissions/{sub_id}",
        token,
        {"data": {"type": "reviewSubmissions", "id": sub_id, "attributes": {"submitted": True}}},
    )
    print("\n✅ Submitted for App Review. Check App Store Connect → App Review.")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--status", action="store_true")
    p.add_argument("--build", default="13")
    p.add_argument("--wait", action="store_true")
    args = p.parse_args()

    if not os.path.exists(KEY_PATH):
        raise SystemExit(f"API key not found: {KEY_PATH}")

    token = make_token()
    if args.status:
        show_status(token)
    else:
        submit(token, args.build, args.wait)


if __name__ == "__main__":
    main()
