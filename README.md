# Musix

An invite-only, ad-free music app for iPhone. Built for people who want Apple Music's polish without the noise, and Spotify's social bits without the ads.

**Native SwiftUI app + WidgetKit widget + Cloudflare backend.** No web views, no ad SDKs, no trackers.

---

## Read this first (the honest bits)

1. **You can't compile iOS apps on Windows.** Apple's toolchain only runs on macOS. So this repo is set up to build the `.ipa` on a free GitHub macOS runner. Push code → GitHub builds it → download the IPA from the Releases page.
2. **Every IPA must be signed for your own iPhone.** The builds here are intentionally *unsigned*. Tools like **Sideloadly** or **AltStore** re-sign them with your Apple ID:
   - **Free Apple ID** — works, but the app must be re-signed every 7 days, max 3 sideloaded apps, and the widget/App Group may fall back to sample data.
   - **Paid Apple Developer ($99/yr)** — 1-year signing, widgets, app groups, TestFlight and App Store all work normally.
3. **Music licensing is the real moat, not the code.** This app ships royalty-free demo audio and a full catalogue pipeline. Streaming Apple Music's or Spotify's catalogue requires licensing deals that no codebase can give you. Think of this as the product, the app and the backend — ready for whatever catalogue you're allowed to stream.
4. **Subscriptions.** Plans are invite/promo-code only, so nothing is charged in-app. If you later sell subscriptions inside the app, Apple requires In-App Purchase (15–30% cut) — that is an App Store rule, not a code choice.

---

## What's included

| Area | What you get |
| --- | --- |
| **Login** | 6-digit email code, sha-256 hashed, 10-minute expiry, 45s resend limit, 5-attempt lockout, JWT (30 days) stored in the Keychain |
| **Plans** | Solo (1), **Duo (2)**, **Family (6)** — invite-only, no public pricing, access + promo codes, single-use redemptions per account |
| **Daily Wrap** | Minutes, tracks, streak, top artist / track / genre, hourly rhythm, 7-day history, shareable image card. Computed **on-device** from playback — nothing uploaded |
| **Playback** | Queue, seek, next/prev, likes, playlists, recents, background audio, lock-screen controls |
| **Animated covers** | Procedural "living gradient" artwork that breathes with playback, plus optional looping video artwork per track |
| **Lock screen** | Now Playing card with generated artwork, elapsed time, play/pause/skip/scrub, plus a small "now playing" state in the widget |
| **Widget** | WidgetKit **Daily Wrap** (small + medium) reading an App Group snapshot, deep-links to the Wrap tab |
| **Offline demo** | No backend needed: tap *Explore in demo mode* to try everything immediately |
| **Extras** | Dark editorial design, generated cover art (no image assets), haptics-friendly buttons, share sheet |

---

## Get an `.ipa` in about 10 minutes

### 1. Put the project on GitHub

From the project folder (PowerShell):

```powershell
git init -b main
git add .
git commit -m "Musix: invite-only music app"
gh auth login
gh repo create musix --source=. --remote=origin --push
```

No GitHub CLI? Create an empty repo on github.com, then:

```powershell
git init -b main
git add .
git commit -m "Musix: invite-only music app"
git remote add origin https://github.com/YOUR_NAME/musix.git
git push -u origin main
```

Or run the helper, which does all of it and optionally tags a release:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\publish-github.ps1 -RepoName musix -Release
```

### 2. Let Actions build the IPA

- **Actions** tab → **Build & release IPA** → **Run workflow** → tick *Publish the IPA to GitHub Releases* → Run.
- That's it. In ~5 minutes the **Releases** page has `Musix.ipa`.

Prefer versioned releases? Push a tag:

```powershell
git tag v1.0.0
git push origin v1.0.0
```

Every tag named `v*` builds and attaches the IPA to a GitHub Release automatically. Every push to `main` also uploads a downloadable build artifact.

### 3. Install on your iPhone

**Sideloadly (Windows — easiest)**

1. Install [Sideloadly](https://sideloadly.io) and *Apple Devices* (or iTunes) on your PC.
2. Plug in the iPhone, unlock it, tap **Trust**.
3. Drag `Musix.ipa` from the GitHub Release into Sideloadly.
4. Enter your Apple ID (a free one is fine) and start.
5. On the iPhone: **Settings → General → VPN & Device Management → your Apple ID → Trust**.
6. Open **Musix**, sign in with an email code, or tap **Explore in demo mode**.

**AltStore / SideStore** — add the `.ipa` as a file in AltStore, sign with your Apple ID, install.

**Mac + Xcode (if you have one)**

```bash
brew install xcodegen
cd ios
xcodegen generate
open Musix.xcodeproj
```

Select your team under *Signing & Capabilities*, pick your iPhone, Run. Or build the IPA from the terminal:

```bash
./scripts/build-ipa.sh   # -> ios/out/Musix.ipa
```

---

## Backend (real email login)

Demo mode runs entirely offline. Real email codes need the API:

```bash
cd backend
npm install
npx wrangler login
npx wrangler d1 create musix-db          # copy the database_id into wrangler.toml
npm run db:remote                        # schema + plans + demo codes + catalogue
npx wrangler secret put JWT_SECRET       # any long random string
npx wrangler secret put RESEND_API_KEY   # optional, but needed to actually send mail
npm run deploy
```

Then point the app at it. The endpoint is **not** stored in the repo — put it in
`ios/Configs/Local.xcconfig` (git-ignored, created by you):

```xcconfig
MUSIX_API_BASE_URL = https:/$()/musix-api.YOUR-SUBDOMAIN.workers.dev
```

The `$()` in the middle is required: `//` starts a comment in `.xcconfig` files.
On CI, set the same value as a repository secret instead
(**Settings → Secrets and variables → Actions → `MUSIX_API_BASE_URL`**), and the
workflow passes it to `xcodebuild` without it ever appearing in the code.

Local development:

```bash
npm run db:local
npm run dev        # http://127.0.0.1:8787
```

With `APP_ENV = "development"` the API returns `dev_code` and the app shows the code on screen, so you can log in without an email provider. `wrangler.toml` ships with `APP_ENV = "production"`, so deploy carefully — use `npx wrangler dev --var APP_ENV:development` for local work.

### Emails

The Worker posts to Resend (`RESEND_API_KEY`). Swap `sendEmail()` in `backend/src/index.ts` for Mailgun/Postmark/SES and nothing else changes. Verify your sending domain in the provider before going live.

### Test access codes

| Code | Plan |
| --- | --- |
| `MUSIX-SOLO-2026` | Solo — 1 seat |
| `MUSIX-DUO-2026` | Duo — 2 seats |
| `MUSIX-FAMILY-6` | Family — 6 seats |
| `PROMO-WRAP-3M` | Duo promo |
| `PROMO-FAMILY-6` | Family promo |

Demo mode accepts anything containing `FAM`/`6`, `DUO`/`2`, or starting with `MUSIX`.

---

## How the pieces fit

```
iPhone
├── Musix.app                  SwiftUI app (iOS 17+)
│   ├── Session                email-code auth, Keychain token, plan state
│   ├── PlayerEngine           AVPlayer + remote commands + Now Playing artwork
│   ├── ListeningStore         on-device playback log -> Daily Wrap
│   ├── MusicStore             catalogue, likes, playlists, recents
│   └── WidgetBridge           writes a snapshot into the App Group
└── MusixWidget.appex          WidgetKit, reads the same App Group

Cloudflare
├── Worker (Hono-less, zero deps)  auth / plans / codes / family / catalogue
└── D1                             users, otp, plans, invite codes, redemptions, invites, tracks
```

Security choices in the API: OTPs are stored as `sha256(email:code)` (never plaintext), expire in 10 minutes, are single-use, rate-limited to one every 45 seconds, and lock after 5 wrong attempts. Session tokens are HS256 JWTs signed with `JWT_SECRET`.

---

## Widget + App Group setup

- App Group: **`group.app.musix.ios`**
- Entitlements: `ios/Musix/Musix.entitlements`, `ios/MusixWidget/MusixWidget.entitlements`
- Shared model: `ios/Shared/MusixShared.swift` (compiled into both targets)

If you use your own Apple Developer account, create the App Group once in the developer portal and enable it for both bundle IDs (`app.musix.ios` and `app.musix.ios.widget`). With a free Apple ID, Xcode/Sideloadly strips the entitlement and the widget shows its sample state — the app itself keeps working.

---

## Project layout

```
.
├── .github/workflows/ios.yml      Hygiene checks + build + release the unsigned IPA
├── ios/
│   ├── project.yml                XcodeGen project definition
│   ├── Configs/Base.xcconfig      Shared build settings (API URL stays empty here)
│   ├── Configs/Local.xcconfig     Your private endpoint — git-ignored, never commit
│   ├── Shared/MusixShared.swift   App <-> widget snapshot
│   ├── Musix/
│   │   ├── App/                   Entry point, root, tab bar
│   │   ├── Core/                  Session, API, player, stores, theme
│   │   ├── Components/            Artwork, animated covers, buttons, rows
│   │   ├── Features/              Auth, Home, Search, Wrap, Library, Plans, Profile, Player
│   │   └── Resources/             Info.plist, app icon, colours
│   └── MusixWidget/               WidgetKit extension
├── backend/                       Cloudflare Worker + D1 schema
├── scripts/                       build-ipa.sh, publish-github.ps1
├── SECURITY.md                    What is safe to publish, what never is
└── README.md
```

---

## Publishing this repo publicly

Everything committed here is world-readable, so the repo is set up to keep
private details out of Git entirely:

| Detail | Where it lives | In the repo? |
| --- | --- | --- |
| API endpoint | `ios/Configs/Local.xcconfig` or the `MUSIX_API_BASE_URL` Actions secret | ❌ |
| `JWT_SECRET`, `RESEND_API_KEY` | `wrangler secret put` / `backend/.dev.vars` | ❌ |
| Cloudflare D1 `database_id` | `backend/wrangler.toml` (replace the placeholder locally) | placeholder only |
| Personal paths, names, emails | — | ❌ |

`ios/Configs/Base.xcconfig` sets `MUSIX_API_BASE_URL` to empty, so a fresh clone
(and every public CI build) runs in offline demo mode. The workflow's `hygiene`
job fails the build if a local config file or a personal path ever gets
committed.

**One thing no repo can hide:** whatever URL you bake into a released `.ipa` can
be extracted from that binary. So if you publish builds with your real API
endpoint compiled in, treat the endpoint as public (put rate limits and auth in
front of it), or release builds in demo mode and keep the configured build for
yourself.

---

## Try this after installing

1. **Demo mode** → Home shows the Daily Wrap card.
2. **Play a track** → artwork animates, mini-player appears.
3. **Lock the phone** → controls + artwork on the lock screen; audio keeps playing.
4. **Add the widget** → long-press home screen → **+** → Musix → Daily Wrap.
5. **Wrap tab** → minutes climb as you listen → **Share my wrap** exports a card.
6. **You → Redeem code** → `MUSIX-FAMILY-6` → plan updates to Family (6 seats).

---

## Roadmap

- **Android** — next platform. Reuse the same REST API; the UI is a Compose port of the five tabs.
- **Real catalogue** — licensed audio URLs via `/v1/catalog`, plus HLS + offline downloads.
- **Family invites** — the API already stores pending invites; wire up the email and the accept screen.
- **Push notifications** — APNs for invite accepted / weekly wrap.
- **CarPlay** — needs the CarPlay audio entitlement from Apple.

---

## Legal / App Store notes

- The demo tracks come from SoundHelix (royalty-free examples) purely so the app is playable out of the box.
- "Apple Music" and "Spotify" are trademarks of their owners. This project is not affiliated with either; it's an independent product concept.
- If you distribute through the App Store: music streaming requires the appropriate licensing, and digital subscriptions must use In-App Purchase.
- Sideloading is fine for personal testing; distributing builds to other people means Apple Developer Program terms apply.

Built to be read, changed and shipped. Start with `ios/Musix/App/MusixApp.swift`.
