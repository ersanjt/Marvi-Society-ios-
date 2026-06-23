import { NextResponse } from "next/server";
import { assertProductionConfig, isSupabaseConfigured } from "@/config/env";

export async function GET() {
  const configError = assertProductionConfig();

  return NextResponse.json({
    status: configError ? "degraded" : "ok",
    supabase: isSupabaseConfigured(),
    timestamp: new Date().toISOString(),
    ...(configError ? { message: configError } : {}),
  });
}
