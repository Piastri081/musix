# Musix setup for Windows — runs everything I can do locally; asks you for 4 secrets.
#
#   & ".\scripts\setup.ps1"
#
# It will:
#   1. Install deps (npm install)
#   2. Create D1 + apply schema + migration
#   3. Set JWT_SECRET, RESEND_API_KEY, ADMIN_TOKEN (via wrangler secret put)
#   4. Create the R2 bucket (optional, for audio + artwork)
#   5. Deploy the Worker
#   6. Write ios/Configs/Local.xcconfig with your Worker URL (git-ignored)
#   7. Print the commands you must run next (GitHub Actions secret + IPA rebuild)
#
# Requires: node/npm, npm script cmd `npm` (must use .cmd), wrangler CLI
#           (run `npx wrangler login` once before this script)
$ErrorActionPreference = "Stop"
Set-Location -Path "C:\Users\Carlh\Downloads\Musix"

function Global:Should-Quit {
    $env:PSCustomObject | Out-Null
    exit
}

Write-Host "==> 0. Prerequisites"
node --version | Out-String
npm --version | Out-String
if (-not (Get-Command npx -ErrorAction SilentlyContinue)) { exit 1 }
if (-not ((Invoke-Expression -LiteralCommand 'npx wrangler --version' 2>$null) -match 'wrangler')) {
    Write-Host "Installing wrangler globally..."
    npm install -g wrangler
}
if (-not ($env:UserDomain)) { Write-Host "Not logged in to Cloudflare. Run: npx wrangler login"; exit 1 }

Write-Host "==> 1. Install backend deps"
if (-not (Test-Path "backend\package.json")) { Write-Error "backend/ package not found"; exit 1 }
(Get-Command npm.cmd -ErrorAction SilentlyContinue) | Out-Null   # ensure npm.cmd path used
cd backend; npm.cmd install --no-audit --no-fund 2>&1 | Select-Object -Last 3

Write-Host "==> 2. Create D1 database"
try { $db = & npx wrangler d1 list --json 2>&1 | ConvertFrom-Json } catch { $db = $null }
if (-not $db) { Write-Host "No d1 databases yet. Creating..."; & npx wrangler d1 create musix-db }
$d = ($db | Where-Object { $_.name -eq 'musix-db' }).uuid
if (-not $d) { Write-Host "Could not find musix-db uuid. Set it manually in backend/wrangler.toml."; exit 1 }
Write-Host "Database id: $d"
if (Select-String -Path backend\wrangler.toml -Pattern 'REPLACE_WITH_YOUR_D1_DATABASE_ID') {
    (Get-Content backend\wrangler.toml -Raw) -replace 'REPLACE_WITH_YOUR_D1_DATABASE_ID', $d | Set-Content backend\wrangler.toml
}

Write-Host "==> 3. Apply schema + OTA migration"
& npx wrangler d1 execute musix-db --remote --file=./schema.sql 2>&1 | Select-Object -Last 3
& npx wrangler d1 execute musix-db --remote --file=./migrations/002_catalog_ota.sql 2>&1 | Select-Object -Last 3

Write-Host "==> 4. Set secrets (you will be prompted for each)"
Write-Host -NoNewline "[JWT_SECRET]"; Read-Host -AsSecureString | ForEach-Object {
    $plain = [Convert]::ToString([System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($_)))
    & npx wrangler secret put JWT_SECRET $plain 2>&1 | Out-Null
}
Write-Host -NoNewline "[RESEND_API_KEY]"; $resend = (Read-Host).Trim()
if ($resend) { & npx wrangler secret put RESEND_API_KEY $resend 2>&1 | Out-Null }
Write-Host -NoNewline "[ADMIN_TOKEN]"; $admin = (Read-Host -AsSecureString | ForEach-Object {
    [Convert]::ToString([System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($_)))
})
& npx wrangler secret put ADMIN_TOKEN $admin 2>&1 | Out-Null

Write-Host "==> 5. Create R2 bucket (optional, for audio + artwork)"
& npx wrangler r2 bucket list 2>&1 | Select-Object -Last 1
if (& npx wrangler r2 bucket list 2>&1 | Select-String -Pattern 'musix-media' -Quiet -CaseSensitive:$false) {
    Write-Host "musix-media already exists"
} else {
    & npx wrangler r2 bucket create musix-media 2>&1 | Select-Object -Last 2
}

Write-Host "==> 6. Deploy the Worker"
& npx wrangler deploy 2>&1 | Select-Object -Last 5

$WORKER_URL = "https://musix-api.workers.dev"

Write-Host "==> 7. Write ios/Configs/Local.xcconfig (git-ignored, local dev only)"
New-Item -ItemType Directory -Force -Path ios\Configs | Out-Null
@'
MUSIX_API_BASE_URL = '$WORKER_URL'
'@ | Set-Content -Path ios\Configs\Local.xcconfig -Encoding UTF8
Write-Host "Wrote ios\Configs\Local.xcconfig"

Write-Host ""
Write-Host "==> 8. GitHub Actions secret (you must do this in the browser)"
Write-Host "   Open: https://github.com/Piastri081/musix/settings/secrets/actions"
Write-Host "   Add secret:"
Write-Host "     Name:    MUSIX_API_BASE_URL"
Write-Host "     Value:   $WORKER_URL"
Write-Host "   (Optional) Add secret:"
Write-Host "     Name:    ADMIN_TOKEN"
Write-Host "     Value:   $admin"

Write-Host "==> 9. Push to GitHub to trigger a release build"
git add -A
git commit -m "setup: connect app to $WORKER_URL" -q
git push origin main

Write-Host ""
Write-Host "Done. Download the IPA from the latest GitHub Actions run,"
Write-Host "re-sign with Sideloadly/AltStore, and open:"
Write-Host "  $WORKER_URL/admin"
Write-Host "  (sign in with the ADMIN_TOKEN you set above)"