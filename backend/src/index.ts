/**
 * Musix API — Cloudflare Worker + D1
 *
 * Endpoints
 *   POST /v1/auth/request-code   { email }            -> { ok, dev_code? }
 *   POST /v1/auth/verify         { email, code }      -> { token, user }
 *   GET  /v1/me                                       -> user
 *   GET  /v1/plans                                    -> { plans }
 *   POST /v1/plans/redeem        { code }             -> { ok, user }
 *   GET  /v1/family                                   -> { members, seats, seats_used }
 *   POST /v1/family/invite       { email }            -> { ok }
 *   GET  /v1/catalog?since=<rev>                      -> { revision, tracks, removed, unchanged }
 *   GET  /v1/media/<key>                              -> audio/artwork bytes (Range supported)
 *
 *   Admin (header: x-musix-admin: $ADMIN_TOKEN)
 *   POST   /v1/admin/tracks      { tracks: [...] }    -> { ok, revision, count }
 *   DELETE /v1/admin/tracks/<id>                      -> { ok, revision }
 *   POST   /v1/admin/media?name=song.mp3              -> { url, key, size }
 *   GET  /health
 */

export interface Env {
  DB: D1Database;
  JWT_SECRET: string;
  RESEND_API_KEY?: string;
  FROM_EMAIL?: string;
  APP_ENV?: string;
  /** Enables over-the-air music + artwork uploads. Set with `wrangler secret put`. */
  ADMIN_TOKEN?: string;
  /** R2 bucket that stores audio and artwork. Optional: you can use external URLs instead. */
  MEDIA?: R2Bucket;
}

interface UserRow {
  id: string;
  email: string;
  display_name: string;
  plan_id: string | null;
  family_owner_id: string | null;
  created_at: string;
}

interface PlanRow {
  id: string;
  name: string;
  seats: number;
  price_label: string;
  invites_only: number;
  tagline: string;
  features: string;
  accent: string;
}

interface TrackRow {
  id: string;
  title: string;
  artist: string;
  album: string;
  duration: number;
  genre: string;
  audio_url: string;
  cover_url: string | null;
  video_url: string | null;
  palette: number;
  sort: number;
  revision: number;
}

interface TrackInput {
  id?: string;
  title?: string;
  artist?: string;
  album?: string;
  duration?: number;
  genre?: string;
  audio_url?: string;
  audioUrl?: string;
  cover_url?: string | null;
  coverUrl?: string | null;
  video_url?: string | null;
  videoUrl?: string | null;
  palette?: number;
  sort?: number;
}

const enc = new TextEncoder();

class HttpError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

// ---------------------------------------------------------------------------
// Entry
// ---------------------------------------------------------------------------

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }

    try {
      return await route(request, env, url);
    } catch (error) {
      if (error instanceof HttpError) {
        return json({ error: error.message }, error.status);
      }
      console.error("unhandled", error);
      return json({ error: "Something went wrong on our side." }, 500);
    }
  },
};

async function route(request: Request, env: Env, url: URL): Promise<Response> {
  const path = url.pathname.replace(/\/+$/, "") || "/";
  const method = request.method;

  if (path === "/health") {
    return json({ ok: true, service: "musix-api", env: env.APP_ENV ?? "production" });
  }

  if (method === "POST" && path === "/v1/auth/request-code") return requestCode(request, env);
  if (method === "POST" && path === "/v1/auth/verify") return verifyCode(request, env);

  if (method === "GET" && path === "/v1/me") {
    const user = await requireUser(request, env);
    return json(await buildProfile(env, user));
  }

  if (method === "GET" && path === "/v1/plans") return listPlans(env);
  if (method === "POST" && path === "/v1/plans/redeem") return redeemCode(request, env);

  if (method === "GET" && path === "/v1/family") {
    const user = await requireUser(request, env);
    return json(await familyFor(env, user));
  }

  if (method === "POST" && path === "/v1/family/invite") {
    const user = await requireUser(request, env);
    return inviteMember(request, env, user);
  }

  if (method === "GET" && path === "/v1/catalog") return catalog(env, url);

  if ((method === "GET" || method === "HEAD") && path.startsWith("/v1/media/")) {
    return serveMedia(request, env, path);
  }

  // --- Admin: over-the-air catalogue updates ---------------------------------
  if (method === "POST" && path === "/v1/admin/tracks") {
    requireAdmin(request, env);
    return upsertTracks(request, env);
  }

  if (method === "DELETE" && path.startsWith("/v1/admin/tracks/")) {
    requireAdmin(request, env);
    return deleteTrack(env, path.slice("/v1/admin/tracks/".length));
  }

  if (method === "POST" && path === "/v1/admin/media") {
    requireAdmin(request, env);
    return uploadMedia(request, env, url);
  }

  return json({ error: "Not found" }, 404);
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

async function requestCode(request: Request, env: Env): Promise<Response> {
  const body = (await request.json().catch(() => ({}))) as { email?: string };
  const email = normalizeEmail(body.email);
  if (!email) throw new HttpError(400, "Enter a valid email address.");

  const now = Date.now();
  const recent = await env.DB.prepare(
    "SELECT created_at FROM otp_codes WHERE email = ?1"
  ).bind(email).first<{ created_at: number }>();

  if (recent && now - recent.created_at < 45_000) {
    throw new HttpError(429, "Hold on a moment before requesting another code.");
  }

  const code = String(Math.floor(100000 + Math.random() * 900000));
  const hashed = await hashCode(email, code);

  await env.DB.prepare("DELETE FROM otp_codes WHERE email = ?1").bind(email).run();
  await env.DB.prepare(
    "INSERT INTO otp_codes (email, code, expires_at, attempts, created_at) VALUES (?1, ?2, ?3, 0, ?4)"
  ).bind(email, hashed, now + 10 * 60 * 1000, now).run();

  let delivered = false;
  try {
    delivered = await sendEmail(env, email, code);
  } catch (error) {
    console.warn("email delivery failed", error);
  }

  const isDev = env.APP_ENV === "development";
  return json({
    ok: true,
    dev_code: isDev ? code : undefined,
    message: delivered ? "Code sent." : "Code created.",
  });
}

async function verifyCode(request: Request, env: Env): Promise<Response> {
  const body = (await request.json().catch(() => ({}))) as { email?: string; code?: string };
  const email = normalizeEmail(body.email);
  const code = (body.code ?? "").trim();

  if (!email) throw new HttpError(400, "Enter a valid email address.");
  if (!/^\d{6}$/.test(code)) throw new HttpError(400, "That code should be 6 digits.");

  const row = await env.DB.prepare(
    "SELECT email, code, expires_at, attempts FROM otp_codes WHERE email = ?1"
  ).bind(email).first<{ email: string; code: string; expires_at: number; attempts: number }>();

  if (!row) throw new HttpError(400, "Request a fresh code first.");
  if (Date.now() > row.expires_at) throw new HttpError(400, "That code expired. Send a new one.");
  if (row.attempts >= 5) throw new HttpError(429, "Too many attempts. Request a new code.");

  const hashed = await hashCode(email, code);
  if (hashed !== row.code) {
    await env.DB.prepare("UPDATE otp_codes SET attempts = attempts + 1 WHERE email = ?1").bind(email).run();
    throw new HttpError(400, "That code isn't right. Try again.");
  }

  await env.DB.prepare("DELETE FROM otp_codes WHERE email = ?1").bind(email).run();

  let user = await env.DB.prepare("SELECT * FROM users WHERE email = ?1").bind(email).first<UserRow>();
  if (!user) {
    const id = `u_${crypto.randomUUID()}`;
    await env.DB.prepare(
      "INSERT INTO users (id, email, display_name, plan_id, family_owner_id, created_at) VALUES (?1, ?2, ?3, NULL, NULL, ?4)"
    ).bind(id, email, displayNameFromEmail(email), new Date().toISOString()).run();

    // A family invite may already be waiting for this address.
    const invites = await env.DB.prepare(
      "SELECT id, plan_id FROM invites WHERE email = ?1 AND status = 'pending'"
    ).bind(email).all<{ id: string; plan_id: string }>();

    if (invites.results.length > 0) {
      await env.DB.prepare("UPDATE users SET plan_id = ?1 WHERE id = ?2")
        .bind(invites.results[0].plan_id, id).run();
      await env.DB.prepare("UPDATE invites SET status = 'accepted' WHERE email = ?1").bind(email).run();
    }

    user = await env.DB.prepare("SELECT * FROM users WHERE id = ?1").bind(id).first<UserRow>();
  }

  if (!user) throw new HttpError(500, "Could not create your account.");

  const token = await signToken(
    { sub: user.id, email: user.email, exp: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30 },
    env.JWT_SECRET
  );

  return json({ token, user: await buildProfile(env, user) });
}

async function requireUser(request: Request, env: Env): Promise<UserRow> {
  const header = request.headers.get("authorization") ?? "";
  const token = header.replace(/^Bearer\s+/i, "").trim();
  if (!token) throw new HttpError(401, "Sign in to continue.");

  const payload = await verifyToken(token, env.JWT_SECRET);
  if (!payload || typeof payload.sub !== "string") throw new HttpError(401, "Your session expired. Sign in again.");

  const user = await env.DB.prepare("SELECT * FROM users WHERE id = ?1").bind(payload.sub).first<UserRow>();
  if (!user) throw new HttpError(401, "Account not found.");
  return user;
}

// ---------------------------------------------------------------------------
// Plans & codes
// ---------------------------------------------------------------------------

async function listPlans(env: Env): Promise<Response> {
  const { results } = await env.DB.prepare(
    "SELECT id, name, seats, price_label, invites_only, tagline, features, accent FROM plans ORDER BY sort ASC"
  ).all<PlanRow>();

  return json({
    plans: results.map((plan) => ({
      id: plan.id,
      name: plan.name,
      seats: plan.seats,
      price_label: plan.price_label,
      invites_only: Boolean(plan.invites_only),
      tagline: plan.tagline,
      features: safeJsonArray(plan.features),
      accent: plan.accent,
    })),
  });
}

async function redeemCode(request: Request, env: Env): Promise<Response> {
  const user = await requireUser(request, env);
  const body = (await request.json().catch(() => ({}))) as { code?: string };
  const code = (body.code ?? "").trim().toUpperCase();
  if (!code) throw new HttpError(400, "Enter an access code.");

  const invite = await env.DB.prepare(
    "SELECT code, plan_id, max_redemptions, redemptions, expires_at FROM invite_codes WHERE code = ?1 COLLATE NOCASE"
  ).bind(code).first<{
    code: string;
    plan_id: string;
    max_redemptions: number;
    redemptions: number;
    expires_at: number | null;
  }>();

  if (!invite) throw new HttpError(404, "That code isn't valid.");
  if (invite.expires_at && Date.now() > invite.expires_at) throw new HttpError(410, "That code has expired.");
  if (invite.redemptions >= invite.max_redemptions) throw new HttpError(409, "That code has been fully claimed.");

  const already = await env.DB.prepare(
    "SELECT id FROM redemptions WHERE code = ?1 AND user_id = ?2"
  ).bind(invite.code, user.id).first();

  if (already) throw new HttpError(409, "You've already used this code.");

  await env.DB.prepare(
    "INSERT INTO redemptions (id, code, user_id, redeemed_at) VALUES (?1, ?2, ?3, ?4)"
  ).bind(`r_${crypto.randomUUID()}`, invite.code, user.id, new Date().toISOString()).run();

  await env.DB.prepare("UPDATE invite_codes SET redemptions = redemptions + 1 WHERE code = ?1")
    .bind(invite.code).run();

  await env.DB.prepare("UPDATE users SET plan_id = ?1 WHERE id = ?2")
    .bind(invite.plan_id, user.id).run();

  const updated = await env.DB.prepare("SELECT * FROM users WHERE id = ?1").bind(user.id).first<UserRow>();
  if (!updated) throw new HttpError(500, "Could not update your plan.");

  return json({ ok: true, user: await buildProfile(env, updated) });
}

// ---------------------------------------------------------------------------
// Household
// ---------------------------------------------------------------------------

async function familyFor(env: Env, user: UserRow): Promise<unknown> {
  const ownerId = user.family_owner_id ?? user.id;
  const seatCount = await seatCountFor(env, user);

  const owner = await env.DB.prepare("SELECT email, display_name FROM users WHERE id = ?1")
    .bind(ownerId).first<{ email: string; display_name: string }>();

  const { results } = await env.DB.prepare(
    "SELECT id, email, display_name FROM users WHERE family_owner_id = ?1 ORDER BY created_at ASC"
  ).bind(ownerId).all<{ id: string; email: string; display_name: string }>();

  const pending = await env.DB.prepare(
    "SELECT id, email FROM invites WHERE owner_id = ?1 AND status = 'pending'"
  ).bind(ownerId).all<{ id: string; email: string }>();

  const members = [
    ...(owner
      ? [{
          id: ownerId,
          email: owner.email,
          display_name: owner.display_name,
          role: ownerId === user.id ? "owner" : "member",
          status: "active",
        }]
      : []),
    ...results.map((member) => ({
      id: member.id,
      email: member.email,
      display_name: member.display_name,
      role: "member",
      status: "active",
    })),
    ...pending.results.map((invite) => ({
      id: invite.id,
      email: invite.email,
      display_name: "",
      role: "invited",
      status: "invited",
    })),
  ];

  return { members, seats: seatCount.seats, seats_used: members.length };
}

async function inviteMember(request: Request, env: Env, user: UserRow): Promise<Response> {
  const body = (await request.json().catch(() => ({}))) as { email?: string };
  const email = normalizeEmail(body.email);
  if (!email) throw new HttpError(400, "Enter a valid email address.");

  const profile = await buildProfile(env, user);
  if (!profile.plan_id || profile.seats <= 1) {
    throw new HttpError(403, "Upgrade to Duo or Family to invite people.");
  }
  if (profile.seats_used >= profile.seats) {
    throw new HttpError(409, "Every seat on your plan is taken.");
  }
  if (email === user.email) throw new HttpError(400, "That's you.");

  const existing = await env.DB.prepare("SELECT id FROM users WHERE email = ?1").bind(email).first();
  const pending = await env.DB.prepare(
    "SELECT id FROM invites WHERE email = ?1 AND status = 'pending'"
  ).bind(email).first();

  if (existing || pending) throw new HttpError(409, "That person is already on a Musix plan.");

  await env.DB.prepare(
    "INSERT INTO invites (id, owner_id, email, plan_id, status, created_at) VALUES (?1, ?2, ?3, ?4, 'pending', ?5)"
  ).bind(`i_${crypto.randomUUID()}`, user.family_owner_id ?? user.id, email, profile.plan_id, new Date().toISOString()).run();

  return json({ ok: true, message: `Invite sent to ${email}.` });
}

async function seatCountFor(env: Env, user: UserRow): Promise<{ seats: number; used: number }> {
  let seats = 1;
  if (user.plan_id) {
    const plan = await env.DB.prepare("SELECT seats FROM plans WHERE id = ?1")
      .bind(user.plan_id).first<{ seats: number }>();
    if (plan) seats = plan.seats;
  }

  const ownerId = user.family_owner_id ?? user.id;
  const row = await env.DB.prepare(
    "SELECT COUNT(*) AS n FROM users WHERE family_owner_id = ?1"
  ).bind(ownerId).first<{ n: number }>();

  return { seats, used: Math.min(seats, 1 + (row?.n ?? 0)) };
}

// ---------------------------------------------------------------------------
// Catalogue (OTA: clients send the revision they already have)
// ---------------------------------------------------------------------------

const CATALOG_COLUMNS =
  "id, title, artist, album, duration, genre, audio_url, cover_url, video_url, palette, sort, revision";

async function catalog(env: Env, url: URL): Promise<Response> {
  const since = Math.max(0, Number.parseInt(url.searchParams.get("since") ?? "0", 10) || 0);

  await env.DB.prepare("INSERT OR IGNORE INTO catalog_meta (id, revision) VALUES (1, 0)").run();

  const meta = await env.DB
    .prepare("SELECT revision, updated_at FROM catalog_meta WHERE id = 1")
    .first<{ revision: number; updated_at: string | null }>();

  const revision = meta?.revision ?? 0;
  const updatedAt = meta?.updated_at ?? null;

  // Nothing changed since the client's last sync: send a tiny response.
  if (since > 0 && since >= revision) {
    return json({ revision, updated_at: updatedAt, unchanged: true, tracks: [], removed: [] });
  }

  const full = since <= 0;

  const tracks = full
    ? (await env.DB.prepare(
        `SELECT ${CATALOG_COLUMNS} FROM tracks ORDER BY sort ASC, title ASC`
      ).all<TrackRow>()).results
    : (await env.DB.prepare(
        `SELECT ${CATALOG_COLUMNS} FROM tracks WHERE revision > ?1 ORDER BY sort ASC, title ASC`
      ).bind(since).all<TrackRow>()).results;

  const removed = full
    ? []
    : (await env.DB.prepare("SELECT id FROM catalog_tombstones WHERE revision > ?1")
        .bind(since).all<{ id: string }>()).results.map((row) => row.id);

  return json({ revision, updated_at: updatedAt, unchanged: false, full, tracks, removed });
}

async function nextRevision(env: Env): Promise<number> {
  await env.DB.prepare("INSERT OR IGNORE INTO catalog_meta (id, revision) VALUES (1, 0)").run();
  await env.DB.prepare(
    "UPDATE catalog_meta SET revision = revision + 1, updated_at = datetime('now') WHERE id = 1"
  ).run();
  const row = await env.DB
    .prepare("SELECT revision FROM catalog_meta WHERE id = 1")
    .first<{ revision: number }>();
  return row?.revision ?? 1;
}

// ---------------------------------------------------------------------------
// Admin: upload / update / remove music without shipping a new app build
// ---------------------------------------------------------------------------

function requireAdmin(request: Request, env: Env): void {
  const expected = env.ADMIN_TOKEN ?? "";
  if (expected.length < 16) {
    throw new HttpError(503, "Music uploads are not configured. Set the ADMIN_TOKEN secret.");
  }
  const provided = request.headers.get("x-musix-admin") ?? "";
  if (!constantTimeEqual(provided, expected)) {
    throw new HttpError(401, "Invalid admin token.");
  }
}

function constantTimeEqual(a: string, b: string): boolean {
  const left = enc.encode(a);
  const right = enc.encode(b);
  let diff = left.length ^ right.length;
  const length = Math.max(left.length, right.length);
  for (let i = 0; i < length; i += 1) {
    diff |= (left[i] ?? 0) ^ (right[i] ?? 0);
  }
  return diff === 0;
}

async function upsertTracks(request: Request, env: Env): Promise<Response> {
  const body = (await request.json().catch(() => null)) as
    | { tracks?: TrackInput[] }
    | TrackInput
    | null;

  if (!body) throw new HttpError(400, "Send a JSON body with a track or a `tracks` array.");

  const list: TrackInput[] = Array.isArray((body as { tracks?: TrackInput[] }).tracks)
    ? ((body as { tracks?: TrackInput[] }).tracks as TrackInput[])
    : [body as TrackInput];

  if (list.length === 0) throw new HttpError(400, "No tracks supplied.");
  if (list.length > 100) throw new HttpError(400, "Upload at most 100 tracks per request.");

  const prepared = list.map((raw, index) => {
    const title = (raw.title ?? "").trim();
    const artist = (raw.artist ?? "").trim();
    const audioUrl = (raw.audio_url ?? raw.audioUrl ?? "").trim();

    if (!title) throw new HttpError(400, `Track ${index + 1}: title is required.`);
    if (!artist) throw new HttpError(400, `Track ${index + 1}: artist is required.`);
    if (!/^https?:\/\//i.test(audioUrl)) {
      throw new HttpError(400, `Track ${index + 1}: audio_url must be an http(s) URL.`);
    }

    return {
      id: raw.id?.trim() || crypto.randomUUID(),
      title,
      artist,
      album: (raw.album ?? "Single").trim() || "Single",
      duration: Math.max(0, Math.round(Number(raw.duration ?? 0)) || 0),
      genre: (raw.genre ?? "Pop").trim() || "Pop",
      audio_url: audioUrl,
      cover_url: raw.cover_url ?? raw.coverUrl ?? null,
      video_url: raw.video_url ?? raw.videoUrl ?? null,
      palette: Math.abs(Math.round(Number(raw.palette ?? index))) % 8,
      sort: Number.isFinite(Number(raw.sort)) ? Number(raw.sort) : index,
    };
  });

  const revision = await nextRevision(env);

  const statement = env.DB.prepare(
    `INSERT INTO tracks (id, title, artist, album, duration, genre, audio_url, cover_url, video_url, palette, sort, revision)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)
     ON CONFLICT(id) DO UPDATE SET
       title = excluded.title,
       artist = excluded.artist,
       album = excluded.album,
       duration = excluded.duration,
       genre = excluded.genre,
       audio_url = excluded.audio_url,
       cover_url = excluded.cover_url,
       video_url = excluded.video_url,
       palette = excluded.palette,
       sort = excluded.sort,
       revision = excluded.revision`
  );

  await env.DB.batch(
    prepared.map((track) =>
      statement.bind(
        track.id, track.title, track.artist, track.album, track.duration, track.genre,
        track.audio_url, track.cover_url, track.video_url, track.palette, track.sort, revision
      )
    )
  );

  return json({ ok: true, revision, count: prepared.length, ids: prepared.map((t) => t.id) });
}

async function deleteTrack(env: Env, rawId: string): Promise<Response> {
  const id = decodeURIComponent(rawId).trim();
  if (!id) throw new HttpError(400, "Track id is required.");

  const revision = await nextRevision(env);
  await env.DB.batch([
    env.DB.prepare("INSERT OR REPLACE INTO catalog_tombstones (id, revision) VALUES (?1, ?2)")
      .bind(id, revision),
    env.DB.prepare("DELETE FROM tracks WHERE id = ?1").bind(id),
  ]);

  return json({ ok: true, revision });
}

async function uploadMedia(request: Request, env: Env, url: URL): Promise<Response> {
  if (!env.MEDIA) throw new HttpError(503, "Media storage is not configured (R2 binding MEDIA).");

  const name = (url.searchParams.get("name") ?? "").trim();
  if (!name) throw new HttpError(400, "Pass a file name, e.g. /v1/admin/media?name=song.mp3");

  const bytes = await request.arrayBuffer();
  if (bytes.byteLength === 0) throw new HttpError(400, "Empty upload.");
  if (bytes.byteLength > 200 * 1024 * 1024) throw new HttpError(413, "Files must be 200 MB or smaller.");

  const safeName = name.toLowerCase().replace(/[^a-z0-9._-]/g, "-");
  const key = `media/${Date.now().toString(36)}-${safeName}`;
  const contentType = request.headers.get("content-type") || guessContentType(safeName);

  await env.MEDIA.put(key, bytes, {
    httpMetadata: {
      contentType,
      cacheControl: "public, max-age=31536000, immutable",
    },
  });

  return json({ ok: true, key, url: `${url.origin}/v1/media/${key}`, size: bytes.byteLength });
}

async function serveMedia(request: Request, env: Env, path: string): Promise<Response> {
  if (!env.MEDIA) throw new HttpError(503, "Media storage is not configured.");

  const key = decodeURIComponent(path.slice("/v1/media/".length));
  if (!key) throw new HttpError(404, "Not found");

  const rangeHeader = request.headers.get("range") ?? "";
  const match = /^bytes=(\d*)-(\d*)$/.exec(rangeHeader.trim());
  let range: { offset: number; length?: number } | null = null;

  if (match && (match[1] || match[2])) {
    const offset = Number.parseInt(match[1] || "0", 10);
    if (match[2]) {
      const end = Number.parseInt(match[2], 10);
      range = { offset, length: Math.max(0, end - offset + 1) };
    } else {
      range = { offset };
    }
  }

  const object = range
    ? await env.MEDIA.get(key, {
        range: range.length !== undefined
          ? { offset: range.offset, length: range.length }
          : { offset: range.offset },
      })
    : await env.MEDIA.get(key);

  if (!object) {
    return json({ error: "Not found" }, 404);
  }

  const headers = new Headers();
  headers.set("content-type", object.httpMetadata?.contentType ?? "application/octet-stream");
  headers.set("accept-ranges", "bytes");
  headers.set("etag", object.httpEtag);
  headers.set("cache-control", object.httpMetadata?.cacheControl ?? "public, max-age=86400");
  for (const [header, value] of Object.entries(corsHeaders())) headers.set(header, value);

  if (range) {
    const total = object.size;
    const end = range.length !== undefined
      ? Math.min(total - 1, range.offset + range.length - 1)
      : total - 1;
    headers.set("content-range", `bytes ${range.offset}-${end}/${total}`);
    headers.set("content-length", String(Math.max(0, end - range.offset + 1)));
    return new Response(request.method === "HEAD" ? null : object.body, { status: 206, headers });
  }

  headers.set("content-length", String(object.size));
  return new Response(request.method === "HEAD" ? null : object.body, { status: 200, headers });
}

function guessContentType(name: string): string {
  if (name.endsWith(".mp3")) return "audio/mpeg";
  if (name.endsWith(".m4a") || name.endsWith(".aac")) return "audio/mp4";
  if (name.endsWith(".flac")) return "audio/flac";
  if (name.endsWith(".wav")) return "audio/wav";
  if (name.endsWith(".mp4") || name.endsWith(".m4v")) return "video/mp4";
  if (name.endsWith(".mov")) return "video/quicktime";
  if (name.endsWith(".jpg") || name.endsWith(".jpeg")) return "image/jpeg";
  if (name.endsWith(".png")) return "image/png";
  if (name.endsWith(".webp")) return "image/webp";
  return "application/octet-stream";
}

// ---------------------------------------------------------------------------
// Profile
// ---------------------------------------------------------------------------

async function buildProfile(env: Env, user: UserRow) {
  let planName: string | null = null;
  let seats = 1;

  if (user.plan_id) {
    const plan = await env.DB.prepare("SELECT name, seats FROM plans WHERE id = ?1")
      .bind(user.plan_id).first<{ name: string; seats: number }>();
    if (plan) {
      planName = plan.name;
      seats = plan.seats;
    }
  }

  const seatCount = await seatCountFor(env, user);

  return {
    id: user.id,
    email: user.email,
    display_name: user.display_name,
    plan_id: user.plan_id,
    plan_name: planName,
    seats,
    seats_used: seatCount.used,
    member_since: (user.created_at ?? "").slice(0, 10),
  };
}

// ---------------------------------------------------------------------------
// Email
// ---------------------------------------------------------------------------

async function sendEmail(env: Env, to: string, code: string): Promise<boolean> {
  if (!env.RESEND_API_KEY) return false;

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      authorization: `Bearer ${env.RESEND_API_KEY}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      from: env.FROM_EMAIL ?? "Musix <login@musix.app>",
      to: [to],
      subject: `${code} is your Musix code`,
      html: `
        <div style="background:#07070b;padding:40px 24px;font-family:-apple-system,Segoe UI,Roboto,sans-serif;color:#f6f6fa">
          <div style="max-width:420px;margin:0 auto">
            <p style="font-size:13px;letter-spacing:2px;color:#8e8ea3;margin:0 0 24px">MUSIX</p>
            <h1 style="font-size:26px;margin:0 0 8px">Your sign-in code</h1>
            <p style="color:#8e8ea3;font-size:14px;margin:0 0 24px">Enter this to finish signing in. It expires in 10 minutes.</p>
            <p style="font-size:38px;letter-spacing:10px;font-weight:700;color:#b8ff3f;margin:0 0 24px">${code}</p>
            <p style="color:#5c5c70;font-size:12px;margin:0">Didn't request this? You can ignore the email.</p>
          </div>
        </div>`,
    }),
  });

  return response.ok;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function normalizeEmail(value?: string): string | null {
  if (!value) return null;
  const email = value.trim().toLowerCase();
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ? email : null;
}

function displayNameFromEmail(email: string): string {
  const local = email.split("@")[0] ?? "listener";
  const first = local.split(/[._-]/)[0] || "listener";
  return first.charAt(0).toUpperCase() + first.slice(1);
}

function safeJsonArray(value: string): string[] {
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed.map(String) : [];
  } catch {
    return [];
  }
}

async function hashCode(email: string, code: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", enc.encode(`${email}:${code}`));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function b64url(input: string | Uint8Array): string {
  const bytes = typeof input === "string" ? enc.encode(input) : input;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function fromB64url(input: string): Uint8Array {
  const padded = input.replace(/-/g, "+").replace(/_/g, "/");
  const pad = padded.length % 4 === 0 ? "" : "=".repeat(4 - (padded.length % 4));
  const binary = atob(padded + pad);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

async function hmac(data: string, secret: string): Promise<string> {
  // Fail closed: never sign or verify with an unset/placeholder secret.
  if (!secret || secret.length < 16) {
    throw new HttpError(500, "Server is not configured. Set the JWT_SECRET secret.");
  }
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign("HMAC", key, enc.encode(data));
  return b64url(new Uint8Array(signature));
}

async function signToken(payload: Record<string, unknown>, secret: string): Promise<string> {
  const header = b64url(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const body = b64url(JSON.stringify(payload));
  const signature = await hmac(`${header}.${body}`, secret);
  return `${header}.${body}.${signature}`;
}

async function verifyToken(token: string, secret: string): Promise<Record<string, any> | null> {
  const parts = token.split(".");
  if (parts.length !== 3) return null;

  const expected = await hmac(`${parts[0]}.${parts[1]}`, secret);
  if (expected !== parts[2]) return null;

  try {
    const decoded = new TextDecoder().decode(fromB64url(parts[1]));
    const payload = JSON.parse(decoded) as Record<string, any>;
    if (typeof payload.exp === "number" && Date.now() / 1000 > payload.exp) return null;
    return payload;
  } catch {
    return null;
  }
}

function corsHeaders(): Record<string, string> {
  return {
    "access-control-allow-origin": "*",
    "access-control-allow-headers": "authorization, content-type, x-musix-admin",
    "access-control-allow-methods": "GET, HEAD, POST, DELETE, OPTIONS",
  };
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      ...corsHeaders(),
    },
  });
}
