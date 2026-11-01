-- Musix 1.1 — over-the-air catalogue.
-- Run ONCE against an existing database:
--   npx wrangler d1 execute musix-db --remote --file=./migrations/002_catalog_ota.sql
--
-- Fresh installs already get this from schema.sql; skip this file in that case.

ALTER TABLE tracks ADD COLUMN cover_url TEXT;
ALTER TABLE tracks ADD COLUMN video_url TEXT;
ALTER TABLE tracks ADD COLUMN revision INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS catalog_meta (
  id         INTEGER PRIMARY KEY CHECK (id = 1),
  revision   INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT
);

CREATE TABLE IF NOT EXISTS catalog_tombstones (
  id       TEXT PRIMARY KEY,
  revision INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_tracks_revision ON tracks(revision);

INSERT OR IGNORE INTO catalog_meta (id, revision) VALUES (1, 0);

-- 1.1 removes the bundled demo audio. Clear the old rows so every device
-- re-syncs a clean catalogue (the app also drops them on first launch).
DELETE FROM tracks;

-- Tell connected devices to re-download the catalogue from scratch.
UPDATE catalog_meta
SET revision = revision + 1,
    updated_at = datetime('now')
WHERE id = 1;
