#!/usr/bin/env python3
"""Reduce a Supabase `db dump --data-only --use-copy` file to what self-hosted Marvi needs.

Keeps every COPY block for public.* and private.*, plus auth.users and auth.identities.
Drops the rest of the Supabase-managed auth schema (sessions, refresh tokens, MFA, audit log)
because those tables do not exist on the VPS. Truncates the kept tables first so rows that
migrations seed (business categories, runtime settings) do not collide with the dump.

Usage: filter-dump.py <in.sql> <out.sql>
"""
import re
import sys

KEEP_SCHEMAS = {"public", "private"}
KEEP_TABLES = {"auth.users", "auth.identities"}
COPY_RE = re.compile(r'^COPY\s+("?[\w]+"?)\."?([\w]+)"?\s')
SETVAL_RE = re.compile(r"setval\('\"?(\w+)\"?\.")


def unquote(name: str) -> str:
    return name.strip('"')


def keep_table(schema: str, table: str) -> bool:
    return schema in KEEP_SCHEMAS or f"{schema}.{table}" in KEEP_TABLES


def main(src: str, dest: str) -> None:
    with open(src, encoding="utf-8") as f:
        lines = f.readlines()

    body = []
    kept_tables = []
    dropped = {}
    in_copy = False
    keep_block = False

    for line in lines:
        if in_copy:
            if keep_block:
                body.append(line)
            if line.rstrip("\n") == "\\.":
                in_copy = False
            continue

        if line.startswith("\\restrict") or line.startswith("\\unrestrict"):
            continue

        m = COPY_RE.match(line)
        if m:
            schema, table = unquote(m.group(1)), unquote(m.group(2))
            in_copy = True
            keep_block = keep_table(schema, table)
            if keep_block:
                kept_tables.append(f'"{schema}"."{table}"')
                body.append(line)
            else:
                dropped[f"{schema}.{table}"] = dropped.get(f"{schema}.{table}", 0) + 1
            continue

        s = SETVAL_RE.search(line)
        if s and unquote(s.group(1)) not in KEEP_SCHEMAS:
            continue

        body.append(line)

    if in_copy:
        sys.exit("dump ends inside a COPY block — file is truncated")

    header = []
    if kept_tables:
        header.append("TRUNCATE " + ", ".join(dict.fromkeys(kept_tables)) + ";\n")

    with open(dest, "w", encoding="utf-8") as f:
        f.writelines(header + body)

    print(f"filter-dump: kept {len(set(kept_tables))} tables, skipped {len(dropped)} Supabase-internal tables")
    if dropped:
        print("  skipped: " + ", ".join(sorted(dropped)))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
