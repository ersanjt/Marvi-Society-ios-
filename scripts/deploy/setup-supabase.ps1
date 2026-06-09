# Supabase setup helper — run from repo root
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRef
)

$ErrorActionPreference = "Stop"
$SupabaseDir = Join-Path $PSScriptRoot "..\..\infra\supabase"

Write-Host "`n=== Marvi Society — Supabase Setup ===" -ForegroundColor Cyan
Write-Host "Project ref: $ProjectRef`n"

Set-Location $SupabaseDir

Write-Host "[1/3] Login to Supabase (browser will open)..." -ForegroundColor Yellow
npx supabase login

Write-Host "`n[2/3] Linking project..." -ForegroundColor Yellow
npx supabase link --project-ref $ProjectRef

Write-Host "`n[3/3] Pushing migrations..." -ForegroundColor Yellow
npx supabase db push

Write-Host "`n=== Done ===" -ForegroundColor Green
Write-Host @"

Next steps:
1. Supabase Dashboard -> Authentication -> Add user (admin)
2. Copy User UUID
3. Run infra/supabase/seed-after-deploy.sql in SQL Editor
4. Copy API keys to apps/web/.env.local

See docs/DEPLOY_WALKTHROUGH_FA.md for full guide.

"@
