import fs from "fs";
import path from "path";
import { createRequire } from "module";

const require = createRequire(path.join(process.env.MARVI_PG_TOOLS, "package.json"));
export const pg = require("pg");
export const { from: copyFrom, to: copyTo } = require("pg-copy-streams");

export const repo = path.resolve(import.meta.dirname, "../../..");
const conn = { host: "127.0.0.1", port: Number(process.env.MARVI_PG_PORT || 55432), user: "postgres" };

export async function connect(database) {
  const c = new pg.Client({ ...conn, database });
  await c.connect();
  c.on("notice", () => {});
  return c;
}

export async function recreateDb(name) {
  const admin = await connect("postgres");
  await admin.query(`DROP DATABASE IF EXISTS ${name} WITH (FORCE)`);
  await admin.query(`CREATE DATABASE ${name}`);
  await admin.end();
}

// Mirrors apply-schema.sh: compat layer, then each migration once, tracked by version.
export async function applySchema(database) {
  const c = await connect(database);
  await c.query(fs.readFileSync(path.join(repo, "infra/selfhost/compat/00_roles_auth_storage.sql"), "utf8"));
  const dir = path.join(repo, "infra/supabase/migrations");
  let applied = 0;
  for (const f of fs.readdirSync(dir).filter((f) => f.endsWith(".sql")).sort()) {
    const base = f.replace(/\.sql$/, "");
    const version = base.split("_")[0];
    const done = await c.query("SELECT 1 FROM supabase_migrations.schema_migrations WHERE version = $1", [version]);
    if (done.rowCount) continue;
    const sql = fs.readFileSync(path.join(dir, f), "utf8").replace(/^.*CREATE EXTENSION[^;\n]*pg_net.*$/gim, "");
    try {
      await c.query("BEGIN");
      await c.query(sql);
      await c.query("INSERT INTO supabase_migrations.schema_migrations (version, name) VALUES ($1, $2) ON CONFLICT DO NOTHING", [
        version, base.slice(version.length + 1),
      ]);
      await c.query("COMMIT");
      applied++;
    } catch (e) {
      await c.query("ROLLBACK").catch(() => {});
      const pos = Number(e.position) || 0;
      const line = pos ? sql.slice(0, pos).split("\n").length : "?";
      throw new Error(`${f} line ${line}: ${e.message}`);
    }
  }
  await c.end();
  return applied;
}
