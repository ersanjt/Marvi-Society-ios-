import { connect } from "./lib.mjs";

const c = await connect(process.argv[2] || "marvi_test");

const results = [];
async function step(name, fn) {
  try {
    const out = await fn();
    results.push({ step: name, ok: "✓", detail: out ?? "" });
  } catch (e) {
    results.push({ step: name, ok: "✗", detail: e.message.slice(0, 140) });
  }
}

async function as(uid, sql, params = []) {
  await c.query("BEGIN");
  try {
    await c.query("SET LOCAL ROLE authenticated");
    await c.query("SELECT set_config('request.jwt.claims', $1, true)", [
      JSON.stringify({ sub: uid, role: "authenticated", email: `${uid.slice(0, 8)}@test.local` }),
    ]);
    const r = await c.query(sql, params);
    await c.query("COMMIT");
    return r.rows;
  } catch (e) {
    await c.query("ROLLBACK");
    throw e;
  }
}

async function asService(sql, params = []) {
  await c.query("BEGIN");
  try {
    await c.query("SET LOCAL ROLE service_role");
    await c.query("SELECT set_config('request.jwt.claims', $1, true)", [JSON.stringify({ role: "service_role" })]);
    const r = await c.query(sql, params);
    await c.query("COMMIT");
    return r.rows;
  } catch (e) {
    await c.query("ROLLBACK");
    throw e;
  }
}

async function asAnon(sql) {
  await c.query("BEGIN");
  try {
    await c.query("SET LOCAL ROLE anon");
    const r = await c.query(sql);
    await c.query("COMMIT");
    return r.rows;
  } catch (e) {
    await c.query("ROLLBACK");
    throw e;
  }
}

const newUser = async (email, meta = {}) =>
  (
    await c.query(
      "INSERT INTO auth.users (id, email, aud, role, raw_user_meta_data, email_confirmed_at) VALUES (gen_random_uuid(), $1, 'authenticated', 'authenticated', $2, now()) RETURNING id",
      [email, meta]
    )
  ).rows[0].id;

let venueOwner, creator, other, offerId, bookingId;

await step("signup trigger creates profile", async () => {
  creator = await newUser("creator@test.local", { full_name: "Test Creator", instagram_handle: "testcreator" });
  other = await newUser("other@test.local", { full_name: "Other" });
  venueOwner = await newUser("venue@test.local", { full_name: "Venue Owner" });
  const r = await c.query("SELECT role, status FROM public.profiles WHERE id = $1", [creator]);
  if (!r.rows.length) throw new Error("no profile row");
  return JSON.stringify(r.rows[0]);
});

await step("seed demo venue + offers", async () => {
  await asService("SELECT public.seed_istanbul_demo($1)", [venueOwner]);
  const r = await c.query("SELECT count(*)::int n FROM public.offers WHERE status = 'live'");
  return `${r.rows[0].n} live offers`;
});

await step("anon reads offers_public", async () => `${(await asAnon("SELECT id FROM public.offers_public")).length} rows`);

await step("creator: confirm 18+", async () => {
  await as(creator, "SELECT public.confirm_age_18()");
});

await step("creator: upsert profile", async () => {
  await as(creator, "SELECT public.upsert_my_creator_profile($1,$2,$3,$4,$5,$6,$7,$8,$9)", [
    "Test Creator", "testcreator", null, "istanbul", "bio", ["food"], ["English"], null, null,
  ]);
});

await step("admin approves creator", async () => {
  await asService("UPDATE public.profiles SET status = 'approved' WHERE id = $1", [creator]);
  await asService("UPDATE public.creator_profiles SET status = 'approved' WHERE user_id = $1", [creator]);
});

await step("creator: fetch_account_context", async () => {
  const r = await as(creator, "SELECT public.fetch_account_context() AS ctx");
  return JSON.stringify(r[0].ctx).slice(0, 100);
});

await step("creator: sees live offers (RLS)", async () => {
  const r = await as(creator, "SELECT id FROM public.offers WHERE status = 'live' AND remaining_slots > 0 AND model = 'instant' ORDER BY created_at LIMIT 1");
  if (!r.length) throw new Error("no visible live offer");
  offerId = r[0].id;
  return offerId;
});

await step("creator: accept_offer", async () => {
  const r = await as(creator, "SELECT * FROM public.accept_offer($1, NULL, NULL)", [offerId]);
  bookingId = r[0]?.id ?? r[0]?.accept_offer?.id ?? r[0]?.accept_offer;
  return JSON.stringify(r[0]).slice(0, 100);
});

await step("slots decremented", async () => {
  const r = await c.query("SELECT capacity, remaining_slots FROM public.offers WHERE id = $1", [offerId]);
  return JSON.stringify(r.rows[0]);
});

await step("creator: sees own booking", async () => {
  const r = await as(creator, "SELECT id, stage FROM public.bookings");
  if (!r.length) throw new Error("booking not visible to owner");
  bookingId = r[0].id;
  return JSON.stringify(r[0]);
});

await step("other user cannot see that booking (RLS)", async () => {
  const r = await as(other, "SELECT id FROM public.bookings");
  if (r.length) throw new Error(`leak: ${r.length} rows`);
  return "0 rows";
});

await step("anon cannot read bookings", async () => {
  try {
    const r = await asAnon("SELECT id FROM public.bookings");
    if (r.length) throw new Error(`leak: ${r.length} rows`);
    return "0 rows";
  } catch (e) {
    if (e.message.startsWith("leak")) throw e;
    return "denied: " + e.message.slice(0, 60);
  }
});

await step("creator: wrong check-in code rejected", async () => {
  try {
    await as(creator, "SELECT public.check_in_booking($1, '0000')", [bookingId]);
  } catch (e) {
    return "rejected: " + e.message.slice(0, 60);
  }
  throw new Error("wrong code accepted");
});

await step("venue: confirm booking", async () => {
  const r = await as(venueOwner, "SELECT stage FROM public.venue_confirm_booking($1)", [bookingId]);
  return JSON.stringify(r[0]);
});

await step("creator cannot read venue check-in code", async () => {
  try {
    const r = await as(creator, "SELECT public.get_booking_check_in_code($1) AS code", [bookingId]);
    if (r[0]?.code) throw new Error("creator can read code");
    return "null";
  } catch (e) {
    if (e.message === "creator can read code") throw e;
    return "denied: " + e.message.slice(0, 50);
  }
});

await step("creator: correct check-in code accepted", async () => {
  const code = (await as(venueOwner, "SELECT public.get_booking_check_in_code($1) AS code", [bookingId]))[0]?.code;
  if (!code) throw new Error("venue got no check-in code");
  const r = await as(creator, "SELECT stage FROM public.check_in_booking($1, $2)", [bookingId, code]);
  return JSON.stringify(r[0]);
});

await step("creator: submit proof", async () => {
  const r = await as(creator, "SELECT stage, proof_status FROM public.submit_proof($1, $2)", [
    bookingId, ["https://instagram.com/p/test"],
  ]);
  return JSON.stringify(r[0]);
});

await step("creator: toggle saved offer (table write via RLS)", async () => {
  await as(creator, "INSERT INTO public.saved_offers (user_id, offer_id) VALUES (auth.uid(), $1)", [offerId]);
  const r = await as(creator, "SELECT count(*)::int n FROM public.saved_offers");
  return `${r[0].n} saved`;
});

await step("other user cannot write saved_offers for creator", async () => {
  try {
    await as(other, "INSERT INTO public.saved_offers (user_id, offer_id) VALUES ($1, $2)", [creator, offerId]);
  } catch (e) {
    return "blocked: " + e.message.slice(0, 60);
  }
  throw new Error("cross-user write allowed");
});

await step("creator: cannot self-promote to admin", async () => {
  try {
    await as(creator, "UPDATE public.profiles SET role = 'admin' WHERE id = auth.uid()");
  } catch (e) {
    return "blocked: " + e.message.slice(0, 60);
  }
  const r = await c.query("SELECT role FROM public.profiles WHERE id = $1", [creator]);
  if (r.rows[0].role === "admin") throw new Error("privilege escalation succeeded");
  return "no-op";
});

await step("email outbox queued (pg_net stub keeps rows pending)", async () => {
  const r = await c.query("SELECT status, count(*)::int n FROM public.email_outbox GROUP BY 1");
  if (!r.rows.length) throw new Error("no outbox rows from signup");
  return JSON.stringify(r.rows);
});

console.table(results);
const failed = results.filter((r) => r.ok === "✗").length;
console.log(failed ? `${failed} failed` : "all passed");
await c.end();
process.exit(failed ? 1 : 0);
