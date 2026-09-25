# Security Policy

## Reporting a vulnerability

Please do not open a public issue for a suspected security vulnerability.

Report security-sensitive findings privately to the repository owner through GitHub. Include:

- the affected component and version or commit;
- clear reproduction steps;
- the expected security impact;
- a minimal proof of concept where appropriate.

Do not include production secrets, private user data, access tokens, signing keys, or live customer information in public discussions.

## Secrets and credentials

This repository must not contain production credentials or private keys. Use local environment files, CI secrets, and platform secret stores for:

- Supabase service-role secrets;
- Apple APNs signing material;
- Android signing credentials;
- email-provider API keys;
- OAuth client secrets;
- database passwords;
- deployment credentials.

Example files may contain placeholders only.

## Supported code

Security fixes are applied to the current `main` branch. Historical snapshots are not guaranteed to receive patches.
