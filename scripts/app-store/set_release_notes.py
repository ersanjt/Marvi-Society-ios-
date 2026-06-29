#!/usr/bin/env python3
"""Ensure an editable App Store version exists and set its "What's New" notes.

Usage: python3 set_release_notes.py --version 1.2
Auth: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (same defaults as asc_submit.py)
"""
import argparse
import json
import os
import time
import urllib.request
import urllib.error

import jwt

KEY_ID = os.environ.get("ASC_KEY_ID", "JT328F7C3Z")
ISSUER_ID = os.environ.get("ASC_ISSUER_ID", "8b84fa76-827a-48b1-bbce-71bdce84ac52")
KEY_PATH = os.environ.get(
    "ASC_KEY_PATH",
    os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8"),
)
BUNDLE_ID = os.environ.get("ASC_BUNDLE_ID", "com.marvisociety.app")
BASE = "https://api.appstoreconnect.apple.com"

NOTES = {
    "en-US": (
        "What's new in this version:\n"
        "• Sign in faster with Apple and Google\n"
        "• Upload a profile photo and cover image\n"
        "• Rate venues and share feedback after your visit\n"
        "• Smoother business onboarding and venue setup\n"
        "• Password reset and email delivery fixes\n"
        "• Security and stability improvements"
    ),
    "tr": (
        "Bu sürümde yenilikler:\n"
        "• Apple ve Google ile daha hızlı giriş\n"
        "• Profil fotoğrafı ve kapak görseli yükleme\n"
        "• Ziyaret sonrası mekanları değerlendirme ve geri bildirim\n"
        "• Daha akıcı işletme kaydı ve mekan kurulumu\n"
        "• Şifre sıfırlama ve e-posta gönderim düzeltmeleri\n"
        "• Güvenlik ve kararlılık iyileştirmeleri"
    ),
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


def get_app(token):
    res = api("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}", token)
    if not res.get("data"):
        raise SystemExit(f"No app for bundle {BUNDLE_ID}")
    return res["data"][0]


def ensure_version(token, app_id, version):
    res = api("GET", f"/v1/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=20", token)
    for v in res.get("data", []):
        if v["attributes"].get("versionString") == version:
            return v["id"]
    res = api(
        "POST",
        "/v1/appStoreVersions",
        token,
        {
            "data": {
                "type": "appStoreVersions",
                "attributes": {"platform": "IOS", "versionString": version},
                "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
            }
        },
    )
    print(f"Created version {version} id={res['data']['id']}")
    time.sleep(3)
    return res["data"]["id"]


def set_notes(token, version_id):
    res = api("GET", f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=50", token)
    existing = {loc["attributes"].get("locale"): loc["id"] for loc in res.get("data", [])}
    print(f"Existing locales: {list(existing.keys())}")

    for locale, whats_new in NOTES.items():
        if locale in existing:
            api(
                "PATCH",
                f"/v1/appStoreVersionLocalizations/{existing[locale]}",
                token,
                {
                    "data": {
                        "type": "appStoreVersionLocalizations",
                        "id": existing[locale],
                        "attributes": {"whatsNew": whats_new},
                    }
                },
            )
            print(f"✓ Updated whatsNew for {locale}")
        else:
            api(
                "POST",
                "/v1/appStoreVersionLocalizations",
                token,
                {
                    "data": {
                        "type": "appStoreVersionLocalizations",
                        "attributes": {"locale": locale, "whatsNew": whats_new},
                        "relationships": {
                            "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}
                        },
                    }
                },
            )
            print(f"✓ Created localization + whatsNew for {locale}")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--version", required=True)
    args = p.parse_args()
    token = make_token()
    app = get_app(token)
    version_id = ensure_version(token, app["id"], args.version)
    set_notes(token, version_id)
    print("Done.")


if __name__ == "__main__":
    main()
