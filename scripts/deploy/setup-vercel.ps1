# Vercel setup helper — run from repo root
param(
    [switch]$Production
)

$ErrorActionPreference = "Stop"
$WebDir = Join-Path $PSScriptRoot "..\..\apps\web"

Write-Host "`n=== Marvi Society — Vercel Setup ===" -ForegroundColor Cyan

if (-not (Test-Path (Join-Path $WebDir ".env.local"))) {
    Write-Host "Creating .env.local from .env.example..." -ForegroundColor Yellow
    Copy-Item (Join-Path $WebDir ".env.example") (Join-Path $WebDir ".env.local")
    Write-Host "Edit apps/web/.env.local with your Supabase keys before deploying.`n" -ForegroundColor Red
}

Set-Location $WebDir

Write-Host "[1/3] Vercel login (browser will open)..." -ForegroundColor Yellow
npx vercel login

Write-Host "`n[2/3] Link project (choose scope, link to existing or create new)..." -ForegroundColor Yellow
Write-Host "When prompted: Root directory = apps/web (if linking from monorepo)`n" -ForegroundColor Gray
npx vercel link

Write-Host "`n[3/3] Deploy..." -ForegroundColor Yellow
if ($Production) {
    npx vercel --prod
} else {
    npx vercel
}

Write-Host "`n=== Done ===" -ForegroundColor Green
Write-Host "Add env vars in Vercel Dashboard if not set: NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY, NEXT_PUBLIC_SITE_URL`n"
