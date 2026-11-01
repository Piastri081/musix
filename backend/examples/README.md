# Publishing music over the air

Musix ships with **no music**. A release build starts with an empty library and
fills it from `GET /v1/catalog`, so adding tracks never requires a new App Store
or IPA release — as soon as you publish them, every installed app picks them up
on its next launch/foreground sync.

> You need the rights to stream anything you upload. NMIXX, Alex Warren and
> every other commercial artist require a licence from their rights holders
> (label/distributor). Musix does not provide, host or bypass those rights.

## 1. Configure the backend once

```bash
cd backend
npx wrangler secret put ADMIN_TOKEN        # long random string, e.g. openssl rand -base64 48
npx wrangler r2 bucket create musix-media  # optional: host audio on your own R2
```

Uncomment the `[[r2_buckets]]` block in `backend/wrangler.toml` if you created
the bucket, then `npm run deploy`. If you skip R2, point `audio_url` at any
http(s) URL you already host (S3, Bunny, Cloudflare Stream, your own CDN).

## 2. Upload the audio (optional)

```bash
./scripts/upload-music.sh track.mp3 cover.jpg
# -> https://musix-api.you.workers.dev/v1/media/media/xxxx-track.mp3
# -> https://musix-api.you.workers.dev/v1/media/media/xxxx-cover.jpg
```

Supported: `mp3`, `m4a`, `aac`, `flac`, `wav`, `mp4`/`mov` (for animated
covers), `jpg`, `png`, `webp`. Max 200 MB per file. Range requests are
supported, so seeking works.

## 3. Publish the track metadata

`POST /v1/admin/tracks` with the `x-musix-admin` header:

```bash
curl -X POST "$MUSIX_API/v1/admin/tracks" \
  -H "x-musix-admin: $MUSIX_ADMIN_TOKEN" \
  -H "content-type: application/json" \
  --data @backend/examples/tracks.sample.json
```

The response contains the new `revision`. Devices that already have the
previous revision receive only the changed tracks.

Remove a track (devices drop it on next sync):

```bash
curl -X DELETE "$MUSIX_API/v1/admin/tracks/<track-id>" \
  -H "x-musix-admin: $MUSIX_ADMIN_TOKEN"
```

## Track fields

| Field | Required | Notes |
| --- | --- | --- |
| `id` | no | Generated if omitted. Reuse it to update a track in place. |
| `title` | yes | |
| `artist` | yes | |
| `album` | no | Defaults to `Single`. |
| `duration` | no | Seconds. The player corrects it once audio loads. |
| `genre` | no | Used by Browse/Search. Defaults to `Pop`. |
| `audio_url` | yes | `http(s)` — MP3, AAC/M4A, FLAC, WAV, HLS `.m3u8`. |
| `cover_url` | no | Falls back to generated gradient artwork. |
| `video_url` | no | Looping video artwork (`mp4`/`mov`). |
| `palette` | no | 0–7, picks the generated gradient when there is no cover. |
| `sort` | no | Ordering in lists (lower first). |

## How the OTA sync works

1. The app stores the catalogue + `revision` on disk.
2. On launch, on foreground and on pull-to-refresh it calls
   `GET /v1/catalog?since=<revision>`.
3. If nothing changed the API returns `{ "unchanged": true }` (a few bytes).
4. Otherwise it returns only the tracks written after that revision plus the
   ids of deleted tracks, and the app merges them in place.
5. A brand-new install (revision 0) receives the full catalogue.
