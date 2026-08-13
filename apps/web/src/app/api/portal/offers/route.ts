import { createClient } from "@/lib/supabase/server";
import { NextResponse } from "next/server";
import { randomUUID } from "crypto";

const MODEL_MAP: Record<string, string> = {
  invitation: "invitation",
  event: "event",
  gift: "gift",
  instant: "instant",
};

function parseLines(raw: FormDataEntryValue | null): string[] {
  if (typeof raw !== "string" || !raw.trim()) return [];
  try {
    const parsed = JSON.parse(raw);
    if (Array.isArray(parsed)) {
      return parsed.map((v) => String(v).trim()).filter(Boolean);
    }
  } catch {
    // fall through to newline split
  }
  return raw
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
}

function formatDateLabel(raw: string): string {
  if (!raw) return "TBD";
  const d = new Date(`${raw}T12:00:00`);
  if (Number.isNaN(d.getTime())) return raw;
  return d.toLocaleDateString("en-US", {
    weekday: "short",
    month: "short",
    day: "numeric",
  });
}

export async function POST(request: Request) {
  const form = await request.formData();
  const title = String(form.get("title") ?? "").trim();
  const model = String(form.get("model") ?? "invitation");
  const slots = Number(form.get("slots") ?? 0);
  const valueLabel = String(form.get("valueLabel") ?? "").trim();
  const dateLabelRaw = String(form.get("dateLabel") ?? "").trim();
  const timeLabel = String(form.get("timeLabel") ?? "").trim();
  const description = String(form.get("description") ?? "").trim();
  const hostNote = String(form.get("hostNote") ?? "").trim();
  const deliverables = parseLines(form.get("deliverables"));
  const requirements = parseLines(form.get("requirements"));
  const image = form.get("image");

  if (!title || !slots || deliverables.length === 0) {
    return NextResponse.json({ error: "Missing required fields" }, { status: 400 });
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const collaborationModel = MODEL_MAP[String(model).toLowerCase()] ?? "invitation";

  let activeVenue: { id: string; category?: string } | null = null;
  const { data: venues, error: venuesError } = await supabase.rpc("fetch_my_venues");

  if (!venuesError && venues?.length) {
    activeVenue =
      venues.find((v: { is_active: boolean }) => v.is_active) ?? venues[0] ?? null;
  }

  if (!activeVenue) {
    const { data: ownedVenues } = await supabase
      .from("venue_profiles")
      .select("id, category")
      .eq("owner_user_id", user.id)
      .order("created_at", { ascending: true })
      .limit(1);

    activeVenue = ownedVenues?.[0] ?? null;
  }

  if (!activeVenue) {
    return NextResponse.json(
      { error: "No venue profile linked to this account. Add a location in the portal." },
      { status: 400 }
    );
  }

  let imageName: string | null = null;
  if (image instanceof File && image.size > 0) {
    const ext = image.name.split(".").pop()?.toLowerCase() || "jpg";
    const path = `${activeVenue.id}/campaigns/${randomUUID()}.${ext}`;
    const bytes = Buffer.from(await image.arrayBuffer());
    const { error: uploadError } = await supabase.storage
      .from("venue-media")
      .upload(path, bytes, {
        contentType: image.type || "image/jpeg",
        upsert: true,
      });

    if (uploadError) {
      return NextResponse.json({ error: uploadError.message }, { status: 500 });
    }

    const { data: publicData } = supabase.storage.from("venue-media").getPublicUrl(path);
    imageName = `${publicData.publicUrl}?v=${Date.now()}`;
  }

  const { data: offerID, error: rpcError } = await supabase.rpc("submit_campaign_for_review", {
    p_title: title,
    p_category: activeVenue.category ?? "dining",
    p_model: collaborationModel,
    p_date_label: formatDateLabel(dateLabelRaw),
    p_value_label: valueLabel || "Complimentary experience",
    p_slots: slots,
    p_deliverables: deliverables,
    ...(venuesError ? {} : { p_venue_id: activeVenue.id }),
    ...(imageName ? { p_image_name: imageName } : {}),
    ...(description ? { p_description: description } : {}),
    ...(timeLabel ? { p_time_label: timeLabel } : {}),
    ...(requirements.length ? { p_requirements: requirements } : {}),
    ...(hostNote ? { p_host_note: hostNote } : {}),
  });

  if (rpcError) {
    return NextResponse.json({ error: rpcError.message }, { status: 500 });
  }

  return NextResponse.json({
    ok: true,
    offerId: offerID,
    message: "Campaign published. Creators can see it on Explore now.",
  });
}
