#!/usr/bin/env bash
# Upload audio/artwork and publish tracks over the air.
#
#   export MUSIX_API="https://musix-api.you.workers.dev"
#   export MUSIX_ADMIN_TOKEN="…"
#   ./scripts/upload-music.sh song.mp3 cover.jpg
#   ./scripts/upload-music.sh --tracks backend/examples/tracks.sample.json
set -euo pipefail

API="${MUSIX_API:?set MUSIX_API to your Worker URL}"
TOKEN="${MUSIX_ADMIN_TOKEN:?set MUSIX_ADMIN_TOKEN}"

content_type() {
  case "${1,,}" in
    *.mp3) echo "audio/mpeg" ;;
    *.m4a|*.aac) echo "audio/mp4" ;;
    *.flac) echo "audio/flac" ;;
    *.wav) echo "audio/wav" ;;
    *.mp4|*.m4v) echo "video/mp4" ;;
    *.mov) echo "video/quicktime" ;;
    *.jpg|*.jpeg) echo "image/jpeg" ;;
    *.png) echo "image/png" ;;
    *.webp) echo "image/webp" ;;
    *) echo "application/octet-stream" ;;
  esac
}

upload() {
  local file="$1"
  [ -f "$file" ] || { echo "No such file: $file" >&2; exit 1; }
  local name
  name="$(basename "$file" | tr ' ' '_' | tr -cd 'A-Za-z0-9._-')"
  echo "Uploading $name…" >&2
  curl -fsS -X POST "${API%/}/v1/admin/media?name=${name}" \
    -H "x-musix-admin: ${TOKEN}" \
    -H "content-type: $(content_type "$file")" \
    --data-binary "@${file}"
  echo
}

if [ "${1:-}" = "--tracks" ]; then
  json="${2:?usage: $0 --tracks <file.json>}"
  curl -fsS -X POST "${API%/}/v1/admin/tracks" \
    -H "x-musix-admin: ${TOKEN}" \
    -H "content-type: application/json" \
    --data-binary "@${json}"
  echo
  exit 0
fi

[ "$#" -gt 0 ] || { echo "usage: $0 <file> [file…] | --tracks <file.json>" >&2; exit 1; }

for file in "$@"; do
  upload "$file"
done
