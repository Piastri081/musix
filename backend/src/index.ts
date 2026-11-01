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
 *   GET  /v1/catalog                                  -> { tracks }
 *   GET  /health
 */

export interface Env {
  DB: D1Database;
  JWT_SECRET: string;
  RESEND_API_KEY?: string;
  FROM_EMAIL?: string;
  APP_ENV?: string;
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
  palette: number;
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

  if (method === "GET" && path === "/v1/catalog") return catalog(env);

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
// Catalogue
// ---------------------------------------------------------------------------

async function catalog(env: Env): Promise<Response> {
  const { results } = await env.DB.prepare(
    "SELECT id, title, artist, album, duration, genre, audio_url, palette FROM tracks ORDER BY sort ASC"
  ).all<TrackRow>();

  return json({ tracks: results });
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
    "access-control-allow-headers": "authorization, content-type",
    "access-control-allow-methods": "GET, POST, OPTIONS",
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
