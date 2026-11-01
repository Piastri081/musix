#!/usr/bin/env bash
# Musix setup — runs everything I can do locally; asks you for 4 secrets.
#
#   ./scripts/setup.sh
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
# Requires: node/npm, wrangler CLI, a logged-in Cloudflare account
#           (run `npx wrangler login` once before this script).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> 0. Prerequisites"
command -v node >/dev/null 2>&1 || { echo "node not found" >&2; exit 1; }
command -v npm  >/dev/null 2>&1 || { echo "npm not found" >&2; exit 1; }
if ! npx wrangler --version >/dev/null 2>&1; then
  echo "wrangler not installed — installing it"
  npm install -g wrangler
fi
npx wrangler whoami >/dev/null 2>&1 || {
  echo "Not logged in to Cloudflare. Run: npx wrangler login"
  exit 1
}

echo "==> 1. Install backend deps"
cd backend
npm install --no-audit --no-fund

echo "==> 2. Create D1 database"
if npx wrangler d1 list 2>/dev/null | grep -q musix-db; then
  echo "musix-db already exists — skipping creation"
else
  npx wrangler d1 create musix-db
fi
DB_ID=$(npx wrangler d1 list --json 2>/dev/null | node -e '
  let s = "";
  process.stdin.on("data", d => s += d);
  process.stdin.on("end", () => {
    const arr = JSON.parse(s || "[]");
    const db = arr.find(d => d.name === "musix-db");
    console.log(db ? db.uuid : "");
  });
')
if [ -z "$DB_ID" ]; then
  echo "Could not read musix-db uuid. Set it manually in backend/wrangler.toml."
else
  echo "Database id: $DB_ID"
  # Update wrangler.toml with the real id (only if it is still the placeholder)
  if grep -q "REPLACE_WITH_YOUR_D1_DATABASE_ID" backend/wrangler.toml; then
    sed -i "s/REPLACE_WITH_YOUR_D1_DATABASE_ID/$DB_ID/" backend/wrangler.toml
  fi
fi

echo "==> 3. Apply schema + OTA migration"
npx wrangler d1 execute musix-db --remote --file=./schema.sql
npx wrangler d1 execute musix-db --remote --file=./migrations/002_catalog_ota.sql

echo "==> 4. Set secrets (you will be prompted for each)"
read -r -s -p "JWT_SECRET (leave blank for a random one): " JWT_SECRET || true
JWT_SECRET="${JWT_SECRET:-$(openssl rand -base64 48)}"
npx wrangler secret put JWT_SECRET <<< "$JWT_SECRET"

read -r -s -p "RESEND_API_KEY (leave blank to skip email sending): " RESEND_API_KEY || true
if [ -n "$RESEND_API_KEY" ]; then
  npx wrangler secret put RESEND_API_KEY <<< "$RESEND_API_KEY"
fi

read -r -s -p "ADMIN_TOKEN (leave blank for a random one): " ADMIN_TOKEN || true
ADMIN_TOKEN="${ADMIN_TOKEN:-$(openssl rand -base64 48)}"
npx wrangler secret put ADMIN_TOKEN <<< "$ADMIN_TOKEN"

echo "==> 5. Create R2 bucket (optional, for audio + artwork)"
if npx wrangler r2 bucket list 2>/dev/null | grep -q musix-media; then
  echo "musix-media already exists"
else
  npx wrangler r2 bucket create musix-media
fi

echo "==> 6. Deploy the Worker"
npx wrangler deploy

WORKER_URL="https://musix-api.workers.dev"

echo "==> 7. Write ios/Configs/Local.xcconfig (git-ignored, local dev only)"
mkdir -p ios/Configs
cat > ios/Configs/Local.xcconfig <<EOF
MUSIX_API_BASE_URL = $WORKER_URL
EOF
echo "Wrote ios/Configs/Local.xcconfig"

echo "==> 8. GitHub Actions secret (you must do this in the browser)"
echo "   Go to: https://github.com/Piastri081/musix/settings/secrets/actions"
echo "   Add secret:"
echo "     Name:  MUSIX_API_BASE_URL"
echo "     Value: $WORKER_URL"
echo "   (Optional) Add secret:"
echo "     Name:  ADMIN_TOKEN"
echo "     Value: $ADMIN_TOKEN"

echo "==> 9. Push to GitHub to trigger a release build"
git add -A
git commit -m "setup: connect app to $WORKER_URL" --allow-empty || true
git push origin main

echo ""
echo "Done. Next: download the IPA from the GitHub Actions run, re-sign with"
echo "Sideloadly or AltStore, and open the admin panel at:"
echo "  $WORKER/admin"
echo "  (sign in with the ADMIN_TOKEN you set above)"