# Changelog

## 1.1.0 — over-the-air music

**Music**
- Removed every bundled demo track (SoundHelix audio). The app now starts with an
  empty library and fills it from your catalogue.
- Real cover art: tracks can carry `cover_url`; artwork shows on Home, Search,
  Player, the mini-player and the lock screen. Generated gradients remain the
  fallback, and `video_url` still drives animated covers.
- OTA catalogue: `/v1/catalog?since=<revision>` returns only what changed, plus a
  tiny `unchanged` response when nothing did. The app syncs on launch, on
  foreground and on pull-to-refresh, and caches the catalogue on-device.
- Publish without a build: `POST /v1/admin/tracks`, `DELETE /v1/admin/tracks/<id>`
  and `POST /v1/admin/media` (R2 storage with HTTP Range support for seeking).
- New upload helpers: `scripts/upload-music.sh`, `scripts/upload-music.ps1` and a
  documented field list in `backend/examples/`.

**Backend**
- `tracks` gained `cover_url`, `video_url` and `revision`; new `catalog_meta` and
  `catalog_tombstones` tables. One-time upgrade: `backend/migrations/002_catalog_ota.sql`.
- Admin routes are protected by `ADMIN_TOKEN` with a constant-time comparison and
  refuse to run when the secret is unset.
- Drop the bundled demo catalogue from `schema.sql`.

**Security**
- Wrapper `JWT_SECRET`/`ADMIN_TOKEN` values are validated before use; the API
  fails closed instead of signing tokens with an empty secret.

## 1.0.0 — first public build

- SwiftUI app: email-code login, Solo/Duo/Family plans, Daily Wrap, search,
  library, playlists, profile.
- Animated cover artwork, lock-screen Now Playing, WidgetKit Daily Wrap widget.
- Cloudflare Worker + D1 backend, unsigned IPA built and published by GitHub
  Actions.
