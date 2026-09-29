import { applySchema, recreateDb } from "./lib.mjs";

const db = process.argv[2] || "marvi_test";
await recreateDb(db);
const first = await applySchema(db);
const second = await applySchema(db);
console.log(`apply: ${first} migrations applied, re-run applied ${second} (expect 0)`);
if (second !== 0) process.exit(1);
