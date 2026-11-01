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
  id        TEXT PRIMARY KEY,
  title     TEXT NOT NULL,
  artist    TEXT NOT NULL,
  album     TEXT NOT NULL,
  duration  INTEGER NOT NULL,
  genre     TEXT NOT NULL,
  audio_url TEXT NOT NULL,
  palette   INTEGER NOT NULL,
  sort      INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_invites_email ON invites(email, status);
CREATE INDEX IF NOT EXISTS idx_users_owner ON users(family_owner_id);
CREATE INDEX IF NOT EXISTS idx_redemptions_code ON redemptions(code);

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
-- Catalogue (royalty-free demo audio — replace with licensed content)
-- ---------------------------------------------------------------------------

INSERT OR REPLACE INTO tracks (id, title, artist, album, duration, genre, audio_url, palette, sort) VALUES
  ('t01','Neon Tide','Vale','Saltwater',372,'Electronic','https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',0,1),
  ('t02','Slow Motion','Kito Marsh','After Hours',318,'R&B','https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',1,2),
  ('t03','Paper Planes','Ivory Hours','Open Window',289,'Indie','https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',2,3),
  ('t04','Midnight Run','Sable','No Signal',404,'Hip-Hop','https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',3,4),
  ('t05','Golden Hour','Lune','Golden Hour',341,'Pop','https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',4,5),
  ('t06','Deep End','Romantic','Static Bloom',267,'Alt','https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',5,6),
  ('t07','Blue Screen','Vale','Saltwater',355,'Electronic','https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3',6,7),
  ('t08','Hold That Thought','Kito Marsh','After Hours',298,'R&B','https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',7,8),
  ('t09','Glass House','Ivory Hours','Open Window',312,'Indie','https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3',2,9),
  ('t10','Late Checkout','Sable','No Signal',376,'Hip-Hop','https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3',3,10),
  ('t11','Cassette Love','Lune','Golden Hour',284,'Pop','https://www.soundhelix.com/examples/mp3/SoundHelix-Song-11.mp3',4,11),
  ('t12','Night Bus','Romantic','Static Bloom',331,'Alt','https://www.soundhelix.com/examples/mp3/SoundHelix-Song-12.mp3',5,12);
