-- Musix schema + seed data
-- Apply with: npx wrangler d1 execute musix-db --remote --file=./schema.sql

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
  id               TEXT PRIMARY KEY,
  email            TEXT UNIQUE NOT NULL,
  display_name     TEXT NOT NULL,
  plan_id          TEXT,
  family_owner_id  TEXT,
  created_at       TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS otp_codes (
  email       TEXT PRIMARY KEY,
  code        TEXT NOT NULL,
  expires_at  INTEGER NOT NULL,
  attempts    INTEGER NOT NULL DEFAULT 0,
  created_at  INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS plans (
  id           TEXT PRIMARY KEY,
  name         TEXT NOT NULL,
  seats        INTEGER NOT NULL,
  price_label  TEXT NOT NULL,
  invites_only INTEGER NOT NULL DEFAULT 1,
  tagline      TEXT NOT NULL,
  features     TEXT NOT NULL,
  accent       TEXT NOT NULL,
  sort         INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS invite_codes (
  code            TEXT PRIMARY KEY,
  plan_id         TEXT NOT NULL,
  max_redemptions INTEGER NOT NULL DEFAULT 1,
  redemptions     INTEGER NOT NULL DEFAULT 0,
  expires_at      INTEGER,
  note            TEXT
);

CREATE TABLE IF NOT EXISTS redemptions (
  id          TEXT PRIMARY KEY,
  code        TEXT NOT NULL,
  user_id     TEXT NOT NULL,
  redeemed_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS invites (
  id         TEXT PRIMARY KEY,
  owner_id   TEXT NOT NULL,
  email      TEXT NOT NULL,
  plan_id    TEXT NOT NULL,
  status     TEXT NOT NULL DEFAULT 'pending',
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS tracks (
  id         TEXT PRIMARY KEY,
  title      TEXT NOT NULL,
  artist     TEXT NOT NULL,
  album      TEXT NOT NULL,
  duration   INTEGER NOT NULL DEFAULT 0,
  genre      TEXT NOT NULL DEFAULT 'Pop',
  audio_url  TEXT NOT NULL,
  cover_url  TEXT,
  video_url  TEXT,
  palette    INTEGER NOT NULL DEFAULT 0,
  sort       INTEGER NOT NULL DEFAULT 0,
  -- Bumped on every write so clients can sync incrementally (OTA updates).
  revision   INTEGER NOT NULL DEFAULT 0
);

-- One row: the catalogue's current revision. Clients send the revision they
-- already have; the API returns only what changed after it.
CREATE TABLE IF NOT EXISTS catalog_meta (
  id         INTEGER PRIMARY KEY CHECK (id = 1),
  revision   INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT
);

-- Deleted track ids, so clients remove them without a full re-download.
CREATE TABLE IF NOT EXISTS catalog_tombstones (
  id       TEXT PRIMARY KEY,
  revision INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_invites_email ON invites(email, status);
CREATE INDEX IF NOT EXISTS idx_users_owner ON users(family_owner_id);
CREATE INDEX IF NOT EXISTS idx_redemptions_code ON redemptions(code);
CREATE INDEX IF NOT EXISTS idx_tracks_revision ON tracks(revision);

INSERT OR IGNORE INTO catalog_meta (id, revision) VALUES (1, 0);

-- ---------------------------------------------------------------------------
-- Plans: pricing is invite-only, so price_label is intentionally not a number.
-- ---------------------------------------------------------------------------

INSERT OR REPLACE INTO plans (id, name, seats, price_label, invites_only, tagline, features, accent, sort) VALUES
  ('solo',   'Solo',   1, 'Invite only', 1, 'Just you, no interruptions.',
   '["1 account","Lossless audio","Daily Wraps","No ads, ever"]', 'pink', 1),
  ('duo',    'Duo',    2, 'Invite only', 1, 'Two accounts, one code.',
   '["2 accounts","Lossless audio","Daily Wraps","Shared playlists"]', 'lime', 2),
  ('family', 'Family', 6, 'Invite only', 1, 'Six seats, one bill.',
   '["6 accounts","Lossless audio","Daily Wraps","Shared library","Separate logins"]', 'violet', 3);

-- ---------------------------------------------------------------------------
-- Demo access + promo codes. Replace before launch.
-- ---------------------------------------------------------------------------

INSERT OR REPLACE INTO invite_codes (code, plan_id, max_redemptions, redemptions, expires_at, note) VALUES
  ('MUSIX-DUO-2026',    'duo',    500, 0, NULL, 'Duo launch invite'),
  ('MUSIX-FAMILY-6',    'family', 500, 0, NULL, 'Family launch invite'),
  ('MUSIX-SOLO-2026',   'solo',   500, 0, NULL, 'Solo launch invite'),
  ('PROMO-WRAP-3M',     'duo',    100, 0, NULL, 'First three months promo'),
  ('PROMO-FAMILY-6',    'family', 100, 0, NULL, 'Family promo');

-- ---------------------------------------------------------------------------
-- Catalogue
--
-- No music ships with this repo. Add tracks over the air with the admin API
-- (see README → "Music catalogue & OTA updates") once you have the rights to
-- stream the audio. The app starts with an empty library and fills it from
-- /v1/catalog.
-- ---------------------------------------------------------------------------
