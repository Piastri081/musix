# Security & privacy notes

Musix is developed in a **public** repository. Anything committed is readable by
anyone, forever, including in Git history. This file lists what must never be
committed and how the repo keeps it out.

## Never commit

| Item | Correct home |
| --- | --- |
| Your Worker URL / API endpoint (if you want it private) | `ios/Configs/Local.xcconfig` (git-ignored) or the `MUSIX_API_BASE_URL` Actions secret |
| `JWT_SECRET` | `npx wrangler secret put JWT_SECRET` |
| `ADMIN_TOKEN` (music uploads) | `npx wrangler secret put ADMIN_TOKEN` |
| `RESEND_API_KEY` (or any email provider key) | `npx wrangler secret put RESEND_API_KEY` |
| Cloudflare API token / account ID | `~/.wrangler` config on your machine |
| Your real D1 `database_id` | `backend/wrangler.toml` locally — the repo keeps a placeholder |
| Email addresses, real names, device UDIDs, screenshots with personal data | nowhere in Git |
| Absolute file paths (`C:\Users\you\...`, `/Users/you/...`) | nowhere in Git |

## How this repo enforces it

- `.gitignore` excludes `ios/Configs/Local.xcconfig`, `backend/.dev.vars`, `.env*`.
- `ios/Configs/Base.xcconfig` sets `MUSIX_API_BASE_URL` to **empty**, so a clone
  builds into offline demo mode and no endpoint ships by default.
- `backend/wrangler.toml` ships `APP_ENV = "production"`; the development-only
  `dev_code` response is off unless you explicitly opt in.
- `backend/.dev.vars.example` documents required secrets with dummy values.
- The `hygiene` job in `.github/workflows/ios.yml` fails the build if:
  - `ios/Configs/Local.xcconfig`, `backend/.dev.vars`, `.env`, or `.env.local`
    are tracked,
  - a personal filesystem path is committed,
  - something shaped like a live API key (`re_…`, `sk_live_…`, `AKIA…`) appears.

## Admin panel (1.1.1+)

- `GET /admin` is a server-rendered console for the catalogue. It requires the
  `ADMIN_TOKEN` secret (≥16 chars, 32+ recommended) and sets an `HttpOnly`,
  `SameSite=Strict` session cookie derived from it via SHA-256. The cookie value
  is never the token itself.
- The panel renders no JavaScript and sends a strict CSP
  (`default-src 'none'; style-src 'unsafe-inline'; form-action 'self'`), so it
  cannot load or execute third-party code.
- Treat the panel URL as sensitive as the token: if `ADMIN_TOKEN` leaks, rotate
  it with `npx wrangler secret put ADMIN_TOKEN` — all existing cookies and
  script headers stop working immediately.
- The panel can publish straight from a phone browser, but uploaded audio is
  capped at 100 MB per request (Cloudflare Workers limit). Split large files or
  host them on your own CDN.

## Music access (1.1+)

- `/v1/catalog` and `/v1/media/*` are intentionally public so playback works
  before/without a session. Anyone with a media URL can stream that file, and
  anyone can read the catalogue. If your catalogue is subscriber-only, put the
  Worker behind a Cloudflare Access rule or switch `serveMedia` to signed URLs
  before publishing.
- `ADMIN_TOKEN` is the only thing standing between the world and your catalogue.
  Use 32+ random characters, keep it in `wrangler secret`, and rotate it if it
  ever appears in a log or shell history.
- Uploaded files are stored under `media/<timestamp>-<name>` with immutable
  cache headers. Deleting the track row does not delete the R2 object; remove
  that separately if you need to reclaim the rights.

## Before you go live

1. Rotate anything that was ever committed, even for a minute. Deleting a file
   in a later commit does not remove it from history.
2. Replace the demo access codes in `backend/schema.sql`
   (`MUSIX-DUO-2026`, `MUSIX-FAMILY-6`, `MUSIX-SOLO-2026`, the `PROMO-*` codes)
   with codes you generate yourself — they are public knowledge now.
3. Set `JWT_SECRET` to a long random value (`openssl rand -base64 48`).
4. Verify your sending domain with your email provider so codes are not spoofed.
5. Keep rate limits (the API already locks OTPs after 5 attempts and throttles
   resends to one per 45 s) and add Cloudflare WAF rules if the API is public.

## Reporting a security issue

Open a private security advisory on the repository (Security → Advisories →
*Report a vulnerability*) rather than a public issue.
