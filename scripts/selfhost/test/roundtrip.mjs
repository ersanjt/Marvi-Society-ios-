// Dump a populated DB in Supabase's data-only COPY format, run filter-dump.py, restore into a
// fresh schema the way restore-dump.sh does, then compare row counts and RLS on restored data.
import fs from "fs";
import os from "os";
import path from "path";
import { execFileSync } from "child_process";
import { pipeline } from "stream/promises";
import { Readable } from "stream";
import { applySchema, connect, copyFrom, copyTo, recreateDb, repo } from "./lib.mjs";

const source = process.argv[2] || "marvi_test";
const target = process.argv[3] || "marvi_restore";

const src = await connect(source);
const tables = (
  await src.query(`
    SELECT n.nspname AS schema, c.relname AS table
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'r' AND (n.nspname IN ('public', 'private') OR (n.nspname = 'auth' AND c.relname IN ('users', 'identities')))
    ORDER BY 1, 2`)
).rows;

async function columns(client, schema, table) {
  const r = await client.query(
    `SELECT a.attname FROM pg_attribute a
     WHERE a.attrelid = format('%I.%I', $1::text, $2::text)::regclass AND a.attnum > 0 AND NOT a.attisdropped AND a.attgenerated = ''
     ORDER BY a.attnum`,
    [schema, table]
  );
  return r.rows.map((x) => `"${x.attname}"`);
}

async function copyOut(client, sql) {
  const chunks = [];
  await pipeline(client.query(copyTo(sql)), async function* (s) {
    for await (const chunk of s) chunks.push(chunk);
  });
  return Buffer.concat(chunks).toString("utf8");
}

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "marvi-rt-"));
const dumpFile = path.join(tmp, "data.sql");
const filtered = path.join(tmp, "filtered.sql");
let dump = "\\restrict FakeToken123\n\nSET statement_timeout = 0;\nSELECT pg_catalog.set_config('search_path', '', false);\n\n";
const sourceCounts = {};
for (const { schema, table } of tables) {
  const cols = await columns(src, schema, table);
  const data = await copyOut(src, `COPY (SELECT ${cols.join(", ")} FROM "${schema}"."${table}") TO STDOUT`);
  sourceCounts[`${schema}.${table}`] = data ? data.split("\n").filter(Boolean).length : 0;
  dump += `COPY "${schema}"."${table}" (${cols.join(", ")}) FROM stdin;\n${data}\\.\n\n`;
}
// Supabase-internal auth tables that do not exist on the VPS must be dropped by the filter.
dump += `COPY "auth"."sessions" ("id", "user_id") FROM stdin;\n00000000-0000-0000-0000-000000000001\t00000000-0000-0000-0000-000000000002\n\\.\n\n`;
dump += `SELECT pg_catalog.setval('"auth"."refresh_tokens_id_seq"', 42, true);\n\\unrestrict FakeToken123\n`;
fs.writeFileSync(dumpFile, dump);
await src.end();

console.log(execFileSync("python3", [path.join(repo, "scripts/selfhost/filter-dump.py"), dumpFile, filtered]).toString().trim());

await recreateDb(target);
await applySchema(target);
const dst = await connect(target);

// Minimal psql emulation: plain statements end with ';', COPY blocks stream until '\.'.
const lines = fs.readFileSync(filtered, "utf8").split("\n");
await dst.query("BEGIN");
await dst.query("SET LOCAL session_replication_role = replica");
try {
  let stmt = "";
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (/^COPY /.test(line)) {
      const rows = [];
      while (lines[++i] !== "\\.") rows.push(lines[i] + "\n");
      await pipeline(Readable.from(rows), dst.query(copyFrom(line.replace(/;$/, ""))));
      continue;
    }
    if (line.startsWith("\\")) throw new Error(`psql meta-command survived filter: ${line}`);
    stmt += line + "\n";
    if (line.trimEnd().endsWith(";")) {
      await dst.query(stmt);
      stmt = "";
    }
  }
  await dst.query("COMMIT");
} catch (e) {
  await dst.query("ROLLBACK");
  throw e;
}

const results = [];
for (const [name, n] of Object.entries(sourceCounts)) {
  const [schema, table] = name.split(".");
  const got = (await dst.query(`SELECT count(*)::int n FROM "${schema}"."${table}"`)).rows[0].n;
  if (got !== n) results.push({ table: name, source: n, restored: got });
}
const leaked = (await dst.query("SELECT to_regclass('auth.sessions') AS t")).rows[0].t;

// Restored creator must still see exactly their own bookings through RLS.
const owner = (
  await dst.query("SELECT cp.user_id FROM public.bookings b JOIN public.creator_profiles cp ON cp.id = b.creator_id LIMIT 1")
).rows[0]?.user_id;
let rls = "no bookings in source";
if (owner) {
  await dst.query("BEGIN");
  await dst.query("SET LOCAL ROLE authenticated");
  await dst.query("SELECT set_config('request.jwt.claims', $1, true)", [JSON.stringify({ sub: owner, role: "authenticated" })]);
  const mine = (await dst.query("SELECT count(*)::int n FROM public.bookings")).rows[0].n;
  await dst.query("ROLLBACK");
  rls = `restored creator sees ${mine} booking(s)`;
  if (mine < 1) results.push({ table: "rls", source: ">=1", restored: mine });
}
await dst.end();
fs.rmSync(tmp, { recursive: true, force: true });

const total = Object.values(sourceCounts).reduce((a, b) => a + b, 0);
console.log(`roundtrip: ${Object.keys(sourceCounts).length} tables, ${total} rows; ${rls}; auth.sessions on VPS: ${leaked ?? "absent"}`);
if (results.length) {
  console.table(results);
  process.exit(1);
}
console.log("roundtrip: all row counts match");
