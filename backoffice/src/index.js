import http from 'node:http';
import crypto from 'node:crypto';
import fs from 'node:fs';
import pg from 'pg';

const port = Number(process.env.BACKOFFICE_PORT || 3000);
const host = process.env.BACKOFFICE_HOST || '0.0.0.0';
const basePath = normalizeBasePath(process.env.BACKOFFICE_BASE_PATH || '/kcc');
const adminToken = process.env.ADMIN_TOKEN || '';
const adminUsername = process.env.ADMIN_USERNAME || 'admin';
const adminCredentials = parseAdminCredentials();
const authMaxFailures = Number(process.env.ADMIN_AUTH_MAX_FAILURES || 5);
const authLockMs = Number(process.env.ADMIN_AUTH_LOCK_SECONDS || 300) * 1000;
const apiBaseUrl =
  process.env.API_INTERNAL_BASE_URL ||
  `http://api:${process.env.API_PORT || 8080}/kcc/v1`;
const saintsAliasFile =
  process.env.SAINTS_ALIAS_FILE || '/app/saint-aliases.json';
const failedAuthAttempts = new Map();

const db = new pg.Pool({
  host: process.env.POSTGRES_HOST || 'db',
  port: Number(process.env.POSTGRES_PORT || 5432),
  database: process.env.POSTGRES_DB,
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD,
});

async function ensureSchema() {
  await db.query(`
    CREATE TABLE IF NOT EXISTS calendar_month_revisions (
      id bigserial PRIMARY KEY,
      year integer NOT NULL,
      month integer NOT NULL,
      action text NOT NULL,
      source text NOT NULL,
      available boolean NOT NULL,
      payload_json jsonb NOT NULL,
      note text,
      created_at timestamptz NOT NULL DEFAULT now(),
      CHECK (year >= 1900 AND year <= 2200),
      CHECK (month >= 1 AND month <= 12)
    )
  `);

  await db.query(`
    CREATE INDEX IF NOT EXISTS calendar_month_revisions_year_month_idx
    ON calendar_month_revisions (year, month, created_at DESC)
  `);

  await db.query(`
    CREATE TABLE IF NOT EXISTS admin_audit_logs (
      id bigserial PRIMARY KEY,
      admin_user text NOT NULL,
      action text NOT NULL,
      target_type text NOT NULL,
      target_id text NOT NULL,
      details_json jsonb NOT NULL DEFAULT '{}'::jsonb,
      ip text,
      user_agent text,
      created_at timestamptz NOT NULL DEFAULT now()
    )
  `);

  await db.query(`
    CREATE INDEX IF NOT EXISTS admin_audit_logs_created_at_idx
    ON admin_audit_logs (created_at DESC, id DESC)
  `);

  await db.query(`
    CREATE TABLE IF NOT EXISTS app_update_policy (
      id integer PRIMARY KEY DEFAULT 1,
      update_mode text NOT NULL DEFAULT 'none',
      ios_update_mode text NOT NULL DEFAULT 'none',
      ios_update_version text NOT NULL DEFAULT '',
      android_update_mode text NOT NULL DEFAULT 'none',
      android_update_version text NOT NULL DEFAULT '',
      force_update_title text NOT NULL DEFAULT '업데이트가 필요합니다',
      force_update_message text NOT NULL DEFAULT '',
      recommended_update_title text NOT NULL DEFAULT '새 버전이 있습니다',
      update_message text NOT NULL DEFAULT '',
      updated_at timestamptz NOT NULL DEFAULT now(),
      CHECK (id = 1),
      CHECK (update_mode IN ('none', 'recommended', 'force')),
      CHECK (ios_update_mode IN ('none', 'recommended', 'force')),
      CHECK (android_update_mode IN ('none', 'recommended', 'force'))
    )
  `);

  await db.query(`
    ALTER TABLE app_update_policy
    ADD COLUMN IF NOT EXISTS ios_update_mode text NOT NULL DEFAULT 'none'
  `);

  await db.query(`
    ALTER TABLE app_update_policy
    ADD COLUMN IF NOT EXISTS ios_update_version text NOT NULL DEFAULT ''
  `);

  await db.query(`
    ALTER TABLE app_update_policy
    ADD COLUMN IF NOT EXISTS android_update_mode text NOT NULL DEFAULT 'none'
  `);

  await db.query(`
    ALTER TABLE app_update_policy
    ADD COLUMN IF NOT EXISTS android_update_version text NOT NULL DEFAULT ''
  `);

  await db.query(`
    ALTER TABLE app_update_policy
    ADD COLUMN IF NOT EXISTS force_update_title text NOT NULL DEFAULT '업데이트가 필요합니다'
  `);

  await db.query(`
    ALTER TABLE app_update_policy
    ADD COLUMN IF NOT EXISTS recommended_update_title text NOT NULL DEFAULT '새 버전이 있습니다'
  `);

  await db.query(`
    CREATE TABLE IF NOT EXISTS saints (
      source_saint_id integer PRIMARY KEY,
      name_ko text NOT NULL,
      name_latin text NOT NULL DEFAULT '',
      feast_month integer,
      feast_day integer,
      status text NOT NULL DEFAULT '',
      kind text NOT NULL DEFAULT '',
      region_ko text NOT NULL DEFAULT '',
      region_en text NOT NULL DEFAULT '',
      year_text text NOT NULL DEFAULT '',
      detail_url text NOT NULL DEFAULT '',
      url text NOT NULL DEFAULT '',
      search_text text NOT NULL DEFAULT '',
      source text NOT NULL DEFAULT 'maria-import',
      updated_at timestamptz NOT NULL DEFAULT now()
    )
  `);

  await db.query(`
    ALTER TABLE saints
    ADD COLUMN IF NOT EXISTS url text NOT NULL DEFAULT ''
  `);

  await db.query(`
    ALTER TABLE saints
    ADD COLUMN IF NOT EXISTS search_text text NOT NULL DEFAULT ''
  `);

  await db.query(`
    UPDATE saints
    SET url = 'https://m.mariasarang.net/saint/bbs_view.asp?index=bbs_saint&no=' || source_saint_id
    WHERE url = ''
  `);

  await db.query(`
    UPDATE saints
    SET search_text = trim(concat_ws(' ', name_ko, name_latin, status, kind, region_ko, region_en, year_text))
    WHERE search_text = ''
  `);

  const saintAliases = loadSaintAliasDoc();
  for (const [id, aliases] of Object.entries(saintAliases.byId)) {
    for (const alias of aliases) {
      await db.query(
        `
          UPDATE saints
          SET search_text = trim(concat_ws(' ', search_text, $2))
          WHERE source_saint_id = $1
            AND search_text NOT ILIKE '%' || $2 || '%'
        `,
        [Number(id), alias],
      );
    }
  }

  for (const [name, aliases] of Object.entries(saintAliases.byName)) {
    for (const alias of aliases) {
      await db.query(
        `
          UPDATE saints
          SET search_text = trim(concat_ws(' ', search_text, $2))
          WHERE (name_ko ILIKE '%' || $1 || '%' OR name_latin ILIKE '%' || $1 || '%')
            AND search_text NOT ILIKE '%' || $2 || '%'
        `,
        [name, alias],
      );
    }
  }

  await db.query(`
    CREATE INDEX IF NOT EXISTS saints_feast_idx ON saints (feast_month, feast_day)
  `);

  await db.query(`
    CREATE INDEX IF NOT EXISTS saints_name_idx ON saints (name_ko)
  `);
}

function loadSaintAliasDoc() {
  try {
    const parsed = JSON.parse(fs.readFileSync(saintsAliasFile, 'utf8'));
    const byName = parsed.byName || {};
    const byId = parsed.byId || (parsed.byName ? {} : parsed);
    return {
      byName: normalizeAliasMap(byName),
      byId: normalizeAliasMap(byId),
    };
  } catch (error) {
    if (error.code !== 'ENOENT') {
      console.warn(`Failed to load saint aliases: ${saintsAliasFile}`, error);
    }
    return { byName: {}, byId: {} };
  }
}

function normalizeAliasMap(value) {
  return Object.fromEntries(
    Object.entries(value).map(([key, aliases]) => [
      String(key).trim(),
      Array.isArray(aliases)
        ? [...new Set(aliases.map(String).map((s) => s.trim()).filter(Boolean))]
        : [],
    ]),
  );
}

function nameAliasesForSaint(doc, nameKo, nameLatin = '') {
  const aliases = new Set();
  const haystack = `${nameKo || ''} ${nameLatin || ''}`;
  for (const [name, values] of Object.entries(doc.byName)) {
    if (name && haystack.includes(name)) {
      for (const alias of values) aliases.add(alias);
    }
  }
  return [...aliases];
}

function saveSaintAliases(sourceSaintId, aliases) {
  const normalizedId = String(Number(sourceSaintId));
  const doc = loadSaintAliasDoc();
  if (aliases.length === 0) {
    delete doc.byId[normalizedId];
  } else {
    doc.byId[normalizedId] = aliases;
  }
  const sortedByName = Object.fromEntries(
    Object.entries(doc.byName)
      .filter(([name, values]) => name && values.length > 0)
      .sort(([a], [b]) => a.localeCompare(b, 'ko')),
  );
  const sortedById = Object.fromEntries(
    Object.entries(doc.byId)
      .filter(([id, values]) => Number.isInteger(Number(id)) && values.length > 0)
      .sort(([a], [b]) => Number(a) - Number(b)),
  );
  fs.writeFileSync(
    saintsAliasFile,
    `${JSON.stringify({ byName: sortedByName, byId: sortedById }, null, 2)}\n`,
  );
}

function normalizeBasePath(value) {
  const trimmed = value.trim().replace(/\/+$/, '');
  if (!trimmed) return '';
  return trimmed.startsWith('/') ? trimmed : `/${trimmed}`;
}

function parseAdminCredentials() {
  const entries = [];
  const rawCredentials = process.env.ADMIN_CREDENTIALS || '';

  if (adminToken) {
    entries.push([adminUsername, adminToken]);
  }

  for (const item of rawCredentials.split(/[\n,]+/)) {
    const trimmed = item.trim();
    if (!trimmed) continue;
    const separator = trimmed.indexOf(':');
    if (separator <= 0) continue;
    const username = trimmed.slice(0, separator).trim();
    const password = trimmed.slice(separator + 1);
    if (username && password) {
      entries.push([username, password]);
    }
  }

  return entries;
}

function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function normalizeJsonText(payload) {
  return `${JSON.stringify(payload, null, 2)}\n`;
}

function diffLines(beforeText, afterText) {
  const before = beforeText.split('\n');
  const after = afterText.split('\n');
  const rows = [];
  let i = 0;
  let j = 0;
  let beforeLine = 1;
  let afterLine = 1;

  while (i < before.length || j < after.length) {
    if (i < before.length && j < after.length && before[i] === after[j]) {
      rows.push({
        type: 'same',
        before: before[i],
        after: after[j],
        beforeLine,
        afterLine,
      });
      i += 1;
      j += 1;
      beforeLine += 1;
      afterLine += 1;
      continue;
    }

    const nextBeforeMatchesAfter =
      i + 1 < before.length && j < after.length && before[i + 1] === after[j];
    const beforeMatchesNextAfter =
      i < before.length && j + 1 < after.length && before[i] === after[j + 1];

    if (nextBeforeMatchesAfter) {
      rows.push({
        type: 'removed',
        before: before[i],
        after: '',
        beforeLine,
        afterLine: '',
      });
      i += 1;
      beforeLine += 1;
      continue;
    }

    if (beforeMatchesNextAfter) {
      rows.push({
        type: 'added',
        before: '',
        after: after[j],
        beforeLine: '',
        afterLine,
      });
      j += 1;
      afterLine += 1;
      continue;
    }

    if (i < before.length && j < after.length) {
      rows.push({
        type: 'changed',
        before: before[i],
        after: after[j],
        beforeLine,
        afterLine,
      });
      i += 1;
      j += 1;
      beforeLine += 1;
      afterLine += 1;
      continue;
    }

    if (i < before.length) {
      rows.push({
        type: 'removed',
        before: before[i],
        after: '',
        beforeLine,
        afterLine: '',
      });
      i += 1;
      beforeLine += 1;
      continue;
    }

    rows.push({
      type: 'added',
      before: '',
      after: after[j],
      beforeLine: '',
      afterLine,
    });
    j += 1;
    afterLine += 1;
  }

  return rows;
}

function sendHtml(res, status, body) {
  res.writeHead(status, {
    'content-type': 'text/html; charset=utf-8',
    'cache-control': 'no-store',
  });
  res.end(body);
}

function sendJson(res, status, body) {
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
  });
  res.end(JSON.stringify(body));
}

function redirect(res, location) {
  res.writeHead(303, { location });
  res.end();
}

function safeEqual(a, b) {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  if (left.length !== right.length) return false;
  return crypto.timingSafeEqual(left, right);
}

function authKey(req, username = '') {
  return `${clientIp(req)}:${username}`;
}

function getAuthLock(req, username = '') {
  const key = authKey(req, username);
  const entry = failedAuthAttempts.get(key);
  if (!entry) return null;

  const now = Date.now();
  if (entry.lockedUntil && entry.lockedUntil > now) {
    return entry;
  }

  if (entry.resetAt <= now) {
    failedAuthAttempts.delete(key);
    return null;
  }

  return entry;
}

function recordAuthSuccess(req, username) {
  failedAuthAttempts.delete(authKey(req, username));
  failedAuthAttempts.delete(authKey(req, ''));
}

function recordAuthFailure(req, username = '') {
  const key = authKey(req, username);
  const now = Date.now();
  const entry = failedAuthAttempts.get(key) || {
    count: 0,
    resetAt: now + authLockMs,
    lockedUntil: 0,
  };

  if (entry.resetAt <= now) {
    entry.count = 0;
    entry.resetAt = now + authLockMs;
    entry.lockedUntil = 0;
  }

  entry.count += 1;
  if (entry.count >= authMaxFailures) {
    entry.lockedUntil = now + authLockMs;
  }
  failedAuthAttempts.set(key, entry);
  return entry;
}

function parseBasicAuth(req) {
  const header = req.headers.authorization || '';
  if (!header.startsWith('Basic ')) {
    return { username: '', password: '' };
  }

  let decoded = '';
  try {
    decoded = Buffer.from(header.slice('Basic '.length), 'base64').toString(
      'utf8',
    );
  } catch {
    return { username: '', password: '' };
  }
  const separator = decoded.indexOf(':');
  const username = separator >= 0 ? decoded.slice(0, separator) : decoded;
  const password = separator >= 0 ? decoded.slice(separator + 1) : '';
  return { username, password };
}

function authenticate(req) {
  if (adminCredentials.length === 0) {
    return { ok: true, username: 'local' };
  }

  const { username, password } = parseBasicAuth(req);
  const lock = getAuthLock(req, username) || getAuthLock(req, '');
  if (lock?.lockedUntil && lock.lockedUntil > Date.now()) {
    return { ok: false, username, lockedUntil: lock.lockedUntil };
  }

  for (const [candidateUser, candidatePassword] of adminCredentials) {
    if (safeEqual(username, candidateUser) && safeEqual(password, candidatePassword)) {
      recordAuthSuccess(req, username);
      return { ok: true, username };
    }
  }

  const failed = recordAuthFailure(req, username);
  return { ok: false, username, lockedUntil: failed.lockedUntil || 0 };
}

function requireAuth(req, res) {
  const auth = authenticate(req);
  if (auth.ok) {
    req.adminUser = auth.username;
    return true;
  }

  const headers = {
    'www-authenticate': 'Basic realm="KCC Backoffice"',
    'content-type': 'text/plain; charset=utf-8',
  };

  let message = 'Authentication required';
  if (auth.lockedUntil && auth.lockedUntil > Date.now()) {
    headers['retry-after'] = String(Math.ceil((auth.lockedUntil - Date.now()) / 1000));
    message = 'Too many failed login attempts. Try again later.';
  }

  res.writeHead(401, headers);
  res.end(message);
  return false;
}

function clientIp(req) {
  const forwardedFor = req.headers['x-forwarded-for'];
  if (typeof forwardedFor === 'string' && forwardedFor.trim()) {
    return forwardedFor.split(',')[0].trim();
  }
  const cfConnectingIp = req.headers['cf-connecting-ip'];
  if (typeof cfConnectingIp === 'string' && cfConnectingIp.trim()) {
    return cfConnectingIp.trim();
  }
  return req.socket.remoteAddress || '';
}

async function readForm(req) {
  const chunks = [];
  for await (const chunk of req) {
    chunks.push(chunk);
  }
  return new URLSearchParams(Buffer.concat(chunks).toString('utf8'));
}

function parseYearMonth(params) {
  const year = Number(params.get('year'));
  const month = Number(params.get('month'));
  if (!Number.isInteger(year) || year < 1900 || year > 2200) {
    throw new Error('invalid_year');
  }
  if (!Number.isInteger(month) || month < 1 || month > 12) {
    throw new Error('invalid_month');
  }
  return { year, month };
}

async function listCalendarMonths() {
  const result = await db.query(`
    SELECT
      year,
      month,
      available,
      source,
      fetched_at,
      updated_at,
      jsonb_array_length(COALESCE(payload_json->'days', '[]'::jsonb)) AS day_count
    FROM calendar_months
    ORDER BY year DESC, month DESC
  `);
  return result.rows;
}

async function listAuditLogs() {
  const result = await db.query(`
    SELECT
      id,
      admin_user,
      action,
      target_type,
      target_id,
      details_json,
      ip,
      user_agent,
      created_at
    FROM admin_audit_logs
    ORDER BY created_at DESC, id DESC
    LIMIT 200
  `);
  return result.rows;
}

async function logAdminAction(req, action, targetType, targetId, details = {}) {
  await db.query(
    `
      INSERT INTO admin_audit_logs (
        admin_user, action, target_type, target_id, details_json, ip, user_agent
      )
      VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7)
    `,
    [
      req.adminUser || 'unknown',
      action,
      targetType,
      targetId,
      JSON.stringify(details),
      clientIp(req),
      req.headers['user-agent'] || '',
    ],
  );
}

async function getAppUpdatePolicy() {
  const result = await db.query(`
    SELECT
      update_mode,
      ios_update_mode,
      ios_update_version,
      android_update_mode,
      android_update_version,
      force_update_title,
      force_update_message,
      recommended_update_title,
      update_message,
      updated_at
    FROM app_update_policy
    WHERE id = 1
  `);

  return (
    result.rows[0] || {
      update_mode: 'none',
      ios_update_mode: 'none',
      ios_update_version: '',
      android_update_mode: 'none',
      android_update_version: '',
      force_update_title: '업데이트가 필요합니다',
      force_update_message: '',
      recommended_update_title: '새 버전이 있습니다',
      update_message: '',
      updated_at: null,
    }
  );
}

async function upsertAppUpdatePolicy(policy) {
  await db.query(
    `
      INSERT INTO app_update_policy (
        id,
        update_mode,
        ios_update_mode,
        ios_update_version,
        android_update_mode,
        android_update_version,
        force_update_title,
        force_update_message,
        recommended_update_title,
        update_message,
        updated_at
      )
      VALUES (1, $1, $2, $3, $4, $5, $6, $7, $8, $9, now())
      ON CONFLICT (id)
      DO UPDATE SET
        update_mode = EXCLUDED.update_mode,
        ios_update_mode = EXCLUDED.ios_update_mode,
        ios_update_version = EXCLUDED.ios_update_version,
        android_update_mode = EXCLUDED.android_update_mode,
        android_update_version = EXCLUDED.android_update_version,
        force_update_title = EXCLUDED.force_update_title,
        force_update_message = EXCLUDED.force_update_message,
        recommended_update_title = EXCLUDED.recommended_update_title,
        update_message = EXCLUDED.update_message,
        updated_at = now()
    `,
    [
      policy.updateMode,
      policy.iosUpdateMode,
      policy.iosUpdateVersion,
      policy.androidUpdateMode,
      policy.androidUpdateVersion,
      policy.forceUpdateTitle,
      policy.forceUpdateMessage,
      policy.recommendedUpdateTitle,
      policy.updateMessage,
    ],
  );
}

async function deleteCalendarMonth(year, month, options = {}) {
  if (options.saveRevision !== false) {
    await saveCalendarRevision(year, month, 'delete', '삭제 전 자동 저장');
  }

  await db.query('DELETE FROM calendar_months WHERE year = $1 AND month = $2', [
    year,
    month,
  ]);
}

async function getCalendarMonth(year, month) {
  const result = await db.query(
    `
      SELECT year, month, available, source, payload_json, fetched_at, updated_at
      FROM calendar_months
      WHERE year = $1 AND month = $2
    `,
    [year, month],
  );
  return result.rows[0] || null;
}

async function getCalendarRevision(id) {
  const result = await db.query(
    `
      SELECT id, year, month, action, source, available, payload_json, note, created_at
      FROM calendar_month_revisions
      WHERE id = $1
    `,
    [id],
  );
  return result.rows[0] || null;
}

async function listCalendarRevisions(year, month) {
  const result = await db.query(
    `
      SELECT
        id,
        year,
        month,
        action,
        source,
        available,
        note,
        created_at,
        jsonb_array_length(COALESCE(payload_json->'days', '[]'::jsonb)) AS day_count
      FROM calendar_month_revisions
      WHERE year = $1 AND month = $2
      ORDER BY created_at DESC, id DESC
    `,
    [year, month],
  );
  return result.rows;
}

async function saveCalendarRevision(year, month, action, note = '') {
  const row = await getCalendarMonth(year, month);
  if (!row) return;

  await db.query(
    `
      INSERT INTO calendar_month_revisions (
        year, month, action, source, available, payload_json, note
      )
      VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7)
    `,
    [
      year,
      month,
      action,
      row.source,
      row.available,
      JSON.stringify(row.payload_json),
      note,
    ],
  );
}

async function updateCalendarMonth(year, month, payload) {
  await saveCalendarRevision(year, month, 'manual_update', '수동 수정 전 자동 저장');

  await db.query(
    `
      UPDATE calendar_months
      SET
        available = $3,
        source = 'manual',
        payload_json = $4::jsonb,
        updated_at = now()
      WHERE year = $1 AND month = $2
    `,
    [year, month, payload.available !== false, JSON.stringify(payload)],
  );
}

async function restoreCalendarRevision(id) {
  const revision = await getCalendarRevision(id);
  if (!revision) {
    throw new Error('revision_not_found');
  }

  await saveCalendarRevision(
    revision.year,
    revision.month,
    'restore',
    `revision ${revision.id} 되돌리기 전 자동 저장`,
  );

  await db.query(
    `
      INSERT INTO calendar_months (
        year, month, available, source, payload_json, fetched_at, updated_at
      )
      VALUES ($1, $2, $3, 'manual', $4::jsonb, now(), now())
      ON CONFLICT (year, month)
      DO UPDATE SET
        available = EXCLUDED.available,
        source = EXCLUDED.source,
        payload_json = EXCLUDED.payload_json,
        updated_at = now()
    `,
    [
      revision.year,
      revision.month,
      revision.available,
      JSON.stringify(revision.payload_json),
    ],
  );

  return revision;
}

async function refreshCalendarMonth(year, month) {
  await saveCalendarRevision(year, month, 'refresh', '재갱신 전 자동 저장');
  await deleteCalendarMonth(year, month, { saveRevision: false });
  const url = `${apiBaseUrl.replace(/\/+$/, '')}/calendar/${year}/${month}`;
  const response = await fetch(url, { signal: AbortSignal.timeout(10000) });
  if (!response.ok) {
    throw new Error(`refresh_failed_${response.status}`);
  }
  await response.arrayBuffer();
}

function navItem(activeNav, key, href, label) {
  const active = activeNav === key ? ' active' : '';
  return `<a class="nav-item${active}" href="${href}">${label}</a>`;
}

function layout(title, content, activeNav = 'calendar') {
  const authNote =
    adminCredentials.length > 0
      ? `Basic Auth enabled · ${adminCredentials.length} admin account(s)`
      : 'ADMIN_TOKEN/ADMIN_CREDENTIALS is not set. Local access only.';

  return `<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHtml(title)}</title>
  <style>
    :root {
      color-scheme: light;
      --bg: #f6f7f8;
      --surface: #ffffff;
      --line: #d8dde3;
      --text: #17202a;
      --muted: #66717f;
      --primary: #0a6b58;
      --danger: #b42318;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: var(--bg);
      color: var(--text);
      font: 14px/1.5 system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    .shell {
      min-height: 100vh;
      display: grid;
      grid-template-columns: 232px minmax(0, 1fr);
    }
    aside {
      background: var(--surface);
      border-right: 1px solid var(--line);
      padding: 20px 16px;
    }
    .brand {
      margin-bottom: 20px;
      padding: 0 8px;
    }
    nav {
      display: grid;
      gap: 6px;
    }
    .nav-item {
      display: block;
      border-radius: 6px;
      padding: 10px 12px;
      color: var(--text);
      text-decoration: none;
      font-weight: 700;
    }
    .nav-item:hover {
      background: #eef4f2;
    }
    .nav-item.active {
      background: var(--primary);
      color: #fff;
    }
    .content {
      min-width: 0;
    }
    header {
      background: var(--surface);
      border-bottom: 1px solid var(--line);
      padding: 18px 24px;
    }
    main {
      max-width: 1280px;
      margin: 0 auto;
      padding: 24px;
    }
    h1 {
      margin: 0;
      font-size: 22px;
      line-height: 1.2;
    }
    .sub {
      margin-top: 6px;
      color: var(--muted);
    }
    .toolbar {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      align-items: end;
      margin-bottom: 18px;
      padding: 16px;
      background: var(--surface);
      border: 1px solid var(--line);
      border-radius: 8px;
    }
    label {
      display: grid;
      gap: 4px;
      color: var(--muted);
      font-size: 12px;
    }
    input {
      width: 110px;
      min-height: 36px;
      border: 1px solid var(--line);
      border-radius: 6px;
      padding: 7px 9px;
      color: var(--text);
      background: #fff;
      font: inherit;
    }
    input.wide {
      width: min(420px, 100%);
    }
    input[type="checkbox"], input[type="radio"] {
      width: auto;
      min-height: auto;
    }
    button, .button {
      min-height: 36px;
      border: 1px solid var(--primary);
      border-radius: 6px;
      padding: 7px 11px;
      background: var(--primary);
      color: #fff;
      font: inherit;
      text-decoration: none;
      cursor: pointer;
    }
    a.button {
      display: inline-flex;
      align-items: center;
    }
    .button.secondary {
      background: #fff;
      color: var(--primary);
    }
    button.secondary {
      background: #fff;
      color: var(--primary);
    }
    button.danger {
      border-color: var(--danger);
      background: var(--danger);
    }
    table {
      width: 100%;
      border-collapse: collapse;
      background: var(--surface);
      border: 1px solid var(--line);
      border-radius: 8px;
      overflow: hidden;
    }
    th, td {
      border-bottom: 1px solid var(--line);
      padding: 10px 12px;
      text-align: left;
      vertical-align: middle;
      white-space: nowrap;
    }
    th {
      color: var(--muted);
      font-size: 12px;
      font-weight: 700;
      background: #fbfbfc;
    }
    tr:last-child td { border-bottom: 0; }
    .actions {
      display: flex;
      gap: 8px;
      justify-content: flex-end;
    }
    .empty {
      background: var(--surface);
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 22px;
      color: var(--muted);
    }
    .message {
      margin-bottom: 14px;
      color: var(--primary);
      font-weight: 700;
    }
    .editor {
      display: grid;
      gap: 14px;
      padding: 16px;
      background: var(--surface);
      border: 1px solid var(--line);
      border-radius: 8px;
    }
    .editor textarea {
      width: 100%;
      min-height: 62vh;
      resize: vertical;
      border: 1px solid var(--line);
      border-radius: 6px;
      padding: 12px;
      color: var(--text);
      background: #fff;
      font: 13px/1.45 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
      tab-size: 2;
    }
    .editor textarea.compact {
      min-height: 88px;
    }
    .form-grid {
      display: grid;
      gap: 12px;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    }
    .platform-panel {
      display: grid;
      gap: 10px;
      padding: 12px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: #fbfbfc;
    }
    .platform-panel h2 {
      margin: 0;
      font-size: 16px;
    }
    .form-row {
      display: grid;
      gap: 6px;
    }
    .check-row {
      display: flex;
      align-items: center;
      gap: 8px;
      color: var(--text);
      font-size: 14px;
    }
    .editor-actions {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      justify-content: space-between;
      align-items: center;
    }
    .warning {
      color: var(--danger);
      font-weight: 700;
    }
    .diff-wrap {
      display: grid;
      gap: 14px;
    }
    .diff-table {
      table-layout: fixed;
    }
    .diff-table td {
      white-space: pre-wrap;
      overflow-wrap: anywhere;
      vertical-align: top;
      font: 12px/1.45 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    }
    .diff-table .line-no {
      width: 72px;
      color: var(--muted);
      text-align: right;
      user-select: none;
    }
    .diff-added td {
      background: #e9f8f0;
    }
    .diff-removed td {
      background: #fff0ee;
    }
    .diff-changed td {
      background: #fff8db;
    }
    .hidden-payload {
      display: none;
    }
    pre {
      margin: 0;
      white-space: pre-wrap;
      overflow-wrap: anywhere;
      font: 12px/1.45 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    }
    @media (max-width: 760px) {
      .shell {
        grid-template-columns: 1fr;
      }
      aside {
        border-right: 0;
        border-bottom: 1px solid var(--line);
      }
      nav {
        grid-template-columns: repeat(3, minmax(0, 1fr));
      }
      .nav-item {
        text-align: center;
      }
      main { padding: 16px; }
      table { display: block; overflow-x: auto; }
    }
  </style>
</head>
<body>
  <div class="shell">
    <aside>
      <div class="brand">
        <h1>KCC Backoffice</h1>
        <div class="sub">${escapeHtml(authNote)}</div>
      </div>
      <nav>
        ${navItem(activeNav, 'calendar', basePath || '/', '전례력 캐시')}
        ${navItem(activeNav, 'saints', `${basePath}/saints`, '성인')}
        ${navItem(activeNav, 'app-update', `${basePath}/app-update-policy`, '업데이트 정책')}
        ${navItem(activeNav, 'audit', `${basePath}/audit-logs`, '감사 로그')}
      </nav>
    </aside>
    <div class="content">
      <header>
        <h1>${escapeHtml(title)}</h1>
      </header>
      <main>${content}</main>
    </div>
  </div>
</body>
</html>`;
}

function monthRows(rows) {
  if (rows.length === 0) {
    return '<div class="empty">저장된 전례력 월별 캐시가 없습니다.</div>';
  }

  const cells = rows
    .map((row) => {
      const year = Number(row.year);
      const month = Number(row.month);
      return `<tr>
        <td>${year}</td>
        <td>${month}</td>
        <td>${escapeHtml(row.source)}</td>
        <td>${row.available ? 'yes' : 'no'}</td>
        <td>${Number(row.day_count || 0)}</td>
        <td>${escapeHtml(new Date(row.fetched_at).toLocaleString('ko-KR'))}</td>
        <td>${escapeHtml(new Date(row.updated_at).toLocaleString('ko-KR'))}</td>
        <td>
          <div class="actions">
            <a class="button secondary" href="${basePath}/calendar/edit?year=${year}&month=${month}">수정</a>
            <a class="button secondary" href="${basePath}/calendar/revisions?year=${year}&month=${month}">이력</a>
            <form method="post" action="${basePath}/calendar/refresh">
              <input type="hidden" name="year" value="${year}">
              <input type="hidden" name="month" value="${month}">
              <button class="secondary" type="submit">재갱신</button>
            </form>
            <form method="post" action="${basePath}/calendar/delete">
              <input type="hidden" name="year" value="${year}">
              <input type="hidden" name="month" value="${month}">
              <button class="danger" type="submit">삭제</button>
            </form>
          </div>
        </td>
      </tr>`;
    })
    .join('');

  return `<table>
    <thead>
      <tr>
        <th>연도</th>
        <th>월</th>
        <th>출처</th>
        <th>사용 가능</th>
        <th>일수</th>
        <th>가져온 시각</th>
        <th>수정 시각</th>
        <th></th>
      </tr>
    </thead>
    <tbody>${cells}</tbody>
  </table>`;
}

async function handleIndex(req, res, url) {
  const rows = await listCalendarMonths();
  const message = url.searchParams.get('message');
  const content = `
    ${message ? `<div class="message">${escapeHtml(message)}</div>` : ''}
    <form class="toolbar" method="post" action="${basePath}/calendar/refresh">
      <label>연도 <input name="year" inputmode="numeric" value="2026"></label>
      <label>월 <input name="month" inputmode="numeric" value="7"></label>
      <button type="submit">캐시 생성/재갱신</button>
    </form>
    ${monthRows(rows)}
  `;
  sendHtml(res, 200, layout('전례력 캐시', content, 'calendar'));
}

function auditLogRows(rows) {
  if (rows.length === 0) {
    return '<div class="empty">저장된 감사 로그가 없습니다.</div>';
  }

  const cells = rows
    .map((row) => {
      const detailsText = normalizeJsonText(row.details_json || {});
      return `<tr>
        <td>${Number(row.id)}</td>
        <td>${escapeHtml(new Date(row.created_at).toLocaleString('ko-KR'))}</td>
        <td>${escapeHtml(row.admin_user)}</td>
        <td>${escapeHtml(row.action)}</td>
        <td>${escapeHtml(row.target_type)}</td>
        <td>${escapeHtml(row.target_id)}</td>
        <td>${escapeHtml(row.ip || '')}</td>
        <td>${escapeHtml(row.user_agent || '')}</td>
        <td><pre>${escapeHtml(detailsText)}</pre></td>
      </tr>`;
    })
    .join('');

  return `<table>
    <thead>
      <tr>
        <th>ID</th>
        <th>시각</th>
        <th>관리자</th>
        <th>작업</th>
        <th>대상</th>
        <th>대상 ID</th>
        <th>IP</th>
        <th>User-Agent</th>
        <th>세부 정보</th>
      </tr>
    </thead>
    <tbody>${cells}</tbody>
  </table>`;
}

async function handleAuditLogs(req, res) {
  const rows = await listAuditLogs();
  const content = `
    <div class="toolbar">
      <a class="button secondary" href="${basePath}">목록으로</a>
    </div>
    <div class="editor">
      <div>
        <h2>감사 로그</h2>
        <div class="sub">최근 관리자 변경 작업 200건입니다. JSON 검증 실패나 diff 확인만 한 경우는 기록하지 않습니다.</div>
      </div>
      ${auditLogRows(rows)}
    </div>
  `;
  sendHtml(res, 200, layout('감사 로그', content, 'audit'));
}


function platformModeChecked(policy, platform, mode) {
  const key = platform === 'ios' ? 'ios_update_mode' : 'android_update_mode';
  return policy[key] === mode ? ' checked' : '';
}

function appUpdatePolicyForm(policy) {
  return `
    <form class="editor" method="post" action="${basePath}/app-update-policy/save">
      <input type="hidden" name="updateMode" value="none">
      <div>
        <h2>업데이트 정책</h2>
        <div class="sub">앱 버전은 1.2.3 형식으로 입력합니다. 현재 앱 버전이 설정 버전보다 낮을 때만 업데이트 안내가 표시됩니다.</div>
      </div>
      <div class="form-grid">
        <div class="platform-panel">
          <h2>iOS</h2>
          <label class="form-row">
            업데이트 기준 버전
            <input name="iosUpdateVersion" class="wide" value="${escapeHtml(policy.ios_update_version)}" placeholder="1.0.1">
          </label>
          <label class="check-row">
            <input type="radio" name="iosUpdateMode" value="none"${platformModeChecked(policy, 'ios', 'none')}>
            안내 없음
          </label>
          <label class="check-row">
            <input type="radio" name="iosUpdateMode" value="recommended"${platformModeChecked(policy, 'ios', 'recommended')}>
            권장 업데이트
          </label>
          <label class="check-row">
            <input type="radio" name="iosUpdateMode" value="force"${platformModeChecked(policy, 'ios', 'force')}>
            강제 업데이트
          </label>
        </div>
        <div class="platform-panel">
          <h2>Android</h2>
          <label class="form-row">
            업데이트 기준 버전
            <input name="androidUpdateVersion" class="wide" value="${escapeHtml(policy.android_update_version)}" placeholder="1.0.1">
          </label>
          <label class="check-row">
            <input type="radio" name="androidUpdateMode" value="none"${platformModeChecked(policy, 'android', 'none')}>
            안내 없음
          </label>
          <label class="check-row">
            <input type="radio" name="androidUpdateMode" value="recommended"${platformModeChecked(policy, 'android', 'recommended')}>
            권장 업데이트
          </label>
          <label class="check-row">
            <input type="radio" name="androidUpdateMode" value="force"${platformModeChecked(policy, 'android', 'force')}>
            강제 업데이트
          </label>
        </div>
      </div>
      <div class="form-grid">
        <label class="form-row">
          강제 업데이트 타이틀
          <input name="forceUpdateTitle" class="wide" value="${escapeHtml(policy.force_update_title)}" placeholder="업데이트가 필요합니다">
        </label>
        <label class="form-row">
          권장 업데이트 타이틀
          <input name="recommendedUpdateTitle" class="wide" value="${escapeHtml(policy.recommended_update_title)}" placeholder="새 버전이 있습니다">
        </label>
      </div>
      <label class="form-row">
        강제 업데이트 메시지
        <textarea class="compact" name="forceUpdateMessage" spellcheck="false">${escapeHtml(policy.force_update_message)}</textarea>
      </label>
      <label class="form-row">
        권장 업데이트 메시지
        <textarea class="compact" name="updateMessage" spellcheck="false">${escapeHtml(policy.update_message)}</textarea>
      </label>
      <div class="editor-actions">
        <div class="sub">강제 업데이트: 업데이트 버튼 1개. 권장 업데이트: 다음에, 업데이트 버튼 2개. 버튼 문구와 스토어 URL은 앱에 고정되어 있습니다.</div>
        <button type="submit">저장</button>
      </div>
    </form>`;
}

async function handleAppUpdatePolicy(req, res, url) {
  const policy = await getAppUpdatePolicy();
  const message = url.searchParams.get('message');
  const content = `
    ${message ? `<div class="message">${escapeHtml(message)}</div>` : ''}
    <div class="diff-wrap">
      ${appUpdatePolicyForm(policy)}
    </div>
  `;
  sendHtml(res, 200, layout('업데이트 정책', content, 'app-update'));
}

function renderEditForm(year, month, payload, message = '') {
  const draftKey = `kcc-calendar-editor-${year}-${month}`;
  const content = `
    <form class="editor" method="post" action="${basePath}/calendar/edit/preview">
      <input type="hidden" name="year" value="${year}">
      <input type="hidden" name="month" value="${month}">
      <div>
        <h2>${year}년 ${month}월 JSON 수정</h2>
        <div class="sub">먼저 JSON 문법을 검증하고 diff를 확인한 뒤, 최종 확인을 눌러야 저장됩니다. 저장하면 이 월의 출처가 <strong>manual</strong>로 바뀝니다.</div>
      </div>
      ${message ? `<div class="message">${escapeHtml(message)}</div>` : ''}
      <textarea id="payload-editor" name="payload" spellcheck="false">${escapeHtml(payload)}</textarea>
      <div class="editor-actions">
        <a class="button secondary" data-clear-draft="true" href="${basePath}">목록으로</a>
        <div class="warning">JSON 문법이 틀리면 diff 확인 단계로 넘어가지 않습니다.</div>
        <button type="submit">JSON 검증 및 diff 확인</button>
      </div>
    </form>
    <script>
      (() => {
        const key = ${JSON.stringify(draftKey)};
        const editor = document.getElementById('payload-editor');
        const draft = sessionStorage.getItem(key);
        if (draft !== null && draft !== editor.value) {
          editor.value = draft;
        }
        editor.addEventListener('input', () => {
          sessionStorage.setItem(key, editor.value);
        });
        document.querySelectorAll('[data-clear-draft="true"]').forEach((node) => {
          node.addEventListener('click', () => sessionStorage.removeItem(key));
        });
      })();
    </script>
  `;
  return layout('KCC Backoffice', content);
}

function revisionRows(rows) {
  if (rows.length === 0) {
    return '<div class="empty">저장된 수정 이력이 없습니다.</div>';
  }

  const cells = rows
    .map((row) => {
      const id = Number(row.id);
      const year = Number(row.year);
      const month = Number(row.month);
      return `<tr>
        <td>${id}</td>
        <td>${escapeHtml(row.action)}</td>
        <td>${escapeHtml(row.source)}</td>
        <td>${row.available ? 'yes' : 'no'}</td>
        <td>${Number(row.day_count || 0)}</td>
        <td>${escapeHtml(row.note || '')}</td>
        <td>${escapeHtml(new Date(row.created_at).toLocaleString('ko-KR'))}</td>
        <td>
          <form method="post" action="${basePath}/calendar/revisions/restore">
            <input type="hidden" name="id" value="${id}">
            <button type="submit">되돌리기</button>
          </form>
        </td>
        <td>
          <a class="button secondary" href="${basePath}/calendar/revisions/view?id=${id}&year=${year}&month=${month}">보기</a>
        </td>
      </tr>`;
    })
    .join('');

  return `<table>
    <thead>
      <tr>
        <th>ID</th>
        <th>작업</th>
        <th>이전 출처</th>
        <th>사용 가능</th>
        <th>일수</th>
        <th>메모</th>
        <th>저장 시각</th>
        <th></th>
        <th></th>
      </tr>
    </thead>
    <tbody>${cells}</tbody>
  </table>`;
}

async function handleRevisions(req, res, url) {
  const { year, month } = parseYearMonth(url.searchParams);
  const rows = await listCalendarRevisions(year, month);
  const message = url.searchParams.get('message');
  const content = `
    ${message ? `<div class="message">${escapeHtml(message)}</div>` : ''}
    <div class="toolbar">
      <a class="button secondary" href="${basePath}">목록으로</a>
      <a class="button secondary" href="${basePath}/calendar/edit?year=${year}&month=${month}">현재 JSON 수정</a>
    </div>
    <div class="editor">
      <div>
        <h2>${year}년 ${month}월 수정 이력</h2>
        <div class="sub">수정, 삭제, 재갱신, 되돌리기 전에 자동 저장된 이전 버전입니다.</div>
      </div>
      ${revisionRows(rows)}
    </div>
  `;
  sendHtml(res, 200, layout('KCC Backoffice', content));
}

async function handleRevisionView(req, res, url) {
  const id = Number(url.searchParams.get('id'));
  if (!Number.isInteger(id) || id < 1) {
    throw new Error('invalid_revision_id');
  }

  const revision = await getCalendarRevision(id);
  if (!revision) {
    sendHtml(
      res,
      404,
      layout('KCC Backoffice', '<div class="empty">수정 이력을 찾을 수 없습니다.</div>'),
    );
    return;
  }

  const payload = normalizeJsonText(revision.payload_json);
  const content = `
    <div class="editor">
      <div>
        <h2>Revision #${Number(revision.id)}</h2>
        <div class="sub">${Number(revision.year)}년 ${Number(revision.month)}월 · ${escapeHtml(revision.action)} · ${escapeHtml(new Date(revision.created_at).toLocaleString('ko-KR'))}</div>
      </div>
      <textarea readonly spellcheck="false">${escapeHtml(payload)}</textarea>
      <div class="editor-actions">
        <a class="button secondary" href="${basePath}/calendar/revisions?year=${Number(revision.year)}&month=${Number(revision.month)}">이력으로</a>
        <form method="post" action="${basePath}/calendar/revisions/restore">
          <input type="hidden" name="id" value="${Number(revision.id)}">
          <button type="submit">이 버전으로 되돌리기</button>
        </form>
      </div>
    </div>
  `;
  sendHtml(res, 200, layout('KCC Backoffice', content));
}

async function handleRevisionRestore(req, res) {
  const form = await readForm(req);
  const id = Number(form.get('id'));
  if (!Number.isInteger(id) || id < 1) {
    throw new Error('invalid_revision_id');
  }

  const revision = await restoreCalendarRevision(id);
  await logAdminAction(
    req,
    'calendar_restore_revision',
    'calendar_month',
    `${Number(revision.year)}-${Number(revision.month)}`,
    { revision_id: Number(revision.id) },
  );
  redirect(
    res,
    `${basePath}/calendar/revisions?year=${Number(revision.year)}&month=${Number(revision.month)}&message=${encodeURIComponent('선택한 이력으로 되돌렸습니다.')}`,
  );
}

function normalizeUpdateMode(value) {
  const mode = String(value || '').trim();
  if (mode !== 'none' && mode !== 'recommended' && mode !== 'force') {
    throw new Error('invalid_update_mode');
  }
  return mode;
}

function normalizePolicyVersion(value, updateMode) {
  const version = String(value || '').trim();
  if (updateMode === 'none' && version === '') return '';
  if (!/^\d+\.\d+\.\d+$/.test(version)) {
    throw new Error('invalid_update_version');
  }
  return version;
}

async function handleAppUpdatePolicySave(req, res) {
  const form = await readForm(req);
  let policy;
  try {
    const iosUpdateMode = normalizeUpdateMode(form.get('iosUpdateMode'));
    const androidUpdateMode = normalizeUpdateMode(form.get('androidUpdateMode'));
    policy = {
      updateMode: normalizeUpdateMode(form.get('updateMode')),
      iosUpdateMode,
      iosUpdateVersion: normalizePolicyVersion(
        form.get('iosUpdateVersion'),
        iosUpdateMode,
      ),
      androidUpdateMode,
      androidUpdateVersion: normalizePolicyVersion(
        form.get('androidUpdateVersion'),
        androidUpdateMode,
      ),
      forceUpdateTitle:
        String(form.get('forceUpdateTitle') || '').trim() ||
        '업데이트가 필요합니다',
      forceUpdateMessage: String(form.get('forceUpdateMessage') || '').trim(),
      recommendedUpdateTitle:
        String(form.get('recommendedUpdateTitle') || '').trim() ||
        '새 버전이 있습니다',
      updateMessage: String(form.get('updateMessage') || '').trim(),
    };
  } catch (error) {
    sendHtml(
      res,
      400,
      layout(
        'KCC Backoffice',
        `<div class="empty">업데이트 정책을 저장하지 않았습니다. 안내 방식은 없음, 권장, 강제 중 하나여야 하며, 기준 버전은 1.2.3 형식이어야 합니다.</div>
        <div class="toolbar"><a class="button secondary" href="${basePath}/app-update-policy">업데이트 정책으로 돌아가기</a></div>`,
        'app-update',
      ),
    );
    return;
  }

  await upsertAppUpdatePolicy(policy);
  await logAdminAction(req, 'app_update_policy_update', 'app_update_policy', 'global', {
    update_mode: policy.updateMode,
    ios_update_mode: policy.iosUpdateMode,
    ios_update_version: policy.iosUpdateVersion,
    android_update_mode: policy.androidUpdateMode,
    android_update_version: policy.androidUpdateVersion,
  });
  redirect(
    res,
    `${basePath}/app-update-policy?message=${encodeURIComponent('업데이트 정책을 저장했습니다.')}`,
  );
}

async function handleEdit(req, res, url) {
  const { year, month } = parseYearMonth(url.searchParams);
  const row = await getCalendarMonth(year, month);
  if (!row) {
    sendHtml(
      res,
      404,
      layout('KCC Backoffice', '<div class="empty">캐시를 찾을 수 없습니다.</div>'),
    );
    return;
  }

  const payload = normalizeJsonText(row.payload_json);
  sendHtml(res, 200, renderEditForm(year, month, payload));
}

async function handleEditRestore(req, res) {
  const form = await readForm(req);
  const { year, month } = parseYearMonth(form);
  const payload = form.get('payload') || '';
  sendHtml(
    res,
    200,
    renderEditForm(
      year,
      month,
      payload,
      'diff 확인 화면에서 돌아왔습니다. 입력하던 내용은 아직 저장되지 않았습니다.',
    ),
  );
}

function renderDiffTable(rows) {
  const visibleRows = rows.filter((row) => row.type !== 'same');
  if (visibleRows.length === 0) {
    return '<div class="empty">변경된 내용이 없습니다.</div>';
  }

  const body = visibleRows
    .map((row) => {
      const klass = `diff-${row.type}`;
      const marker =
        row.type === 'added' ? '+' : row.type === 'removed' ? '-' : '~';
      return `<tr class="${klass}">
        <td class="line-no">${escapeHtml(row.beforeLine)}</td>
        <td>${marker}</td>
        <td>${escapeHtml(row.before)}</td>
        <td class="line-no">${escapeHtml(row.afterLine)}</td>
        <td>${escapeHtml(row.after)}</td>
      </tr>`;
    })
    .join('');

  return `<table class="diff-table">
    <thead>
      <tr>
        <th>이전 줄</th>
        <th></th>
        <th>이전 값</th>
        <th>수정 줄</th>
        <th>수정 값</th>
      </tr>
    </thead>
    <tbody>${body}</tbody>
  </table>`;
}

async function handleEditPreview(req, res) {
  const form = await readForm(req);
  const { year, month } = parseYearMonth(form);
  const row = await getCalendarMonth(year, month);
  if (!row) {
    sendHtml(
      res,
      404,
      layout('KCC Backoffice', '<div class="empty">캐시를 찾을 수 없습니다.</div>'),
    );
    return;
  }

  const payloadText = form.get('payload') || '';
  let payload;
  try {
    payload = JSON.parse(payloadText);
  } catch (error) {
    sendHtml(
      res,
      400,
      layout(
        'KCC Backoffice',
        `<div class="empty">JSON 문법 오류로 저장하지 않았습니다: ${escapeHtml(error.message)}</div>
        <form method="post" action="${basePath}/calendar/edit/restore">
          <input type="hidden" name="year" value="${year}">
          <input type="hidden" name="month" value="${month}">
          <textarea class="hidden-payload" name="payload">${escapeHtml(payloadText)}</textarea>
          <button class="secondary" type="submit">수정 화면으로 돌아가기</button>
        </form>`,
      ),
    );
    return;
  }

  const beforeText = normalizeJsonText(row.payload_json);
  const afterText = normalizeJsonText(payload);
  const draftKey = `kcc-calendar-editor-${year}-${month}`;
  const rows = diffLines(beforeText, afterText);
  const hasChanges = rows.some((row) => row.type !== 'same');
  const content = `
    <div class="diff-wrap">
      <div class="editor">
        <div>
          <h2>${year}년 ${month}월 수정 diff 확인</h2>
          <div class="sub">JSON 문법 검증을 통과했습니다. 아래 변경 내용을 확인한 뒤 최종 저장을 눌러야 DB에 반영됩니다.</div>
        </div>
        ${renderDiffTable(rows)}
        <div class="editor-actions">
          <form method="post" action="${basePath}/calendar/edit/restore">
            <input type="hidden" name="year" value="${year}">
            <input type="hidden" name="month" value="${month}">
            <textarea class="hidden-payload" name="payload">${escapeHtml(afterText)}</textarea>
            <button class="secondary" type="submit">수정 화면으로 돌아가기</button>
          </form>
          <form method="post" action="${basePath}/calendar/edit/commit">
            <input type="hidden" name="year" value="${year}">
            <input type="hidden" name="month" value="${month}">
            <textarea class="hidden-payload" name="payload">${escapeHtml(afterText)}</textarea>
            <button data-clear-draft="true" type="submit"${hasChanges ? '' : ' disabled'}>최종 저장</button>
          </form>
        </div>
      </div>
    </div>
    <script>
      (() => {
        const key = ${JSON.stringify(draftKey)};
        document.querySelectorAll('[data-clear-draft="true"]').forEach((node) => {
          node.addEventListener('click', () => sessionStorage.removeItem(key));
        });
      })();
    </script>
  `;
  sendHtml(res, 200, layout('KCC Backoffice', content));
}

async function handlePost(req, res, action) {
  const form = await readForm(req);
  const { year, month } = parseYearMonth(form);

  if (action === 'delete') {
    await deleteCalendarMonth(year, month);
    await logAdminAction(req, 'calendar_delete', 'calendar_month', `${year}-${month}`, {
      year,
      month,
    });
    redirect(res, `${basePath}?message=${encodeURIComponent('캐시를 삭제했습니다.')}`);
    return;
  }

  if (action === 'refresh') {
    await refreshCalendarMonth(year, month);
    await logAdminAction(req, 'calendar_refresh', 'calendar_month', `${year}-${month}`, {
      year,
      month,
    });
    redirect(res, `${basePath}?message=${encodeURIComponent('캐시를 재갱신했습니다.')}`);
    return;
  }

  if (action === 'edit') {
    const payloadText = form.get('payload') || '';
    let payload;
    try {
      payload = JSON.parse(payloadText);
    } catch (error) {
      sendHtml(
        res,
        400,
        layout(
          'KCC Backoffice',
          `<div class="empty">JSON 문법 오류로 저장하지 않았습니다: ${escapeHtml(error.message)}</div>
          <form method="post" action="${basePath}/calendar/edit/restore">
            <input type="hidden" name="year" value="${year}">
            <input type="hidden" name="month" value="${month}">
            <textarea class="hidden-payload" name="payload">${escapeHtml(payloadText)}</textarea>
            <button class="secondary" type="submit">수정 화면으로 돌아가기</button>
          </form>`,
        ),
      );
      return;
    }

    await updateCalendarMonth(year, month, payload);
    await logAdminAction(req, 'calendar_manual_update', 'calendar_month', `${year}-${month}`, {
      year,
      month,
      available: payload.available !== false,
    });
    redirect(res, `${basePath}?message=${encodeURIComponent('수동 수정 내용을 최종 저장했습니다.')}`);
    return;
  }

  sendJson(res, 404, { error: 'not_found' });
}

// ---------------------------------------------------------------------------
// 성인(聖人) 관리
// ---------------------------------------------------------------------------

const SAINTS_PAGE_SIZE = 50;

function buildSaintsWhere(q, month, day) {
  const where = [];
  const args = [];
  if (q) {
    args.push(`%${q}%`);
    where.push(`(name_ko ILIKE $${args.length} OR name_latin ILIKE $${args.length} OR search_text ILIKE $${args.length})`);
  }
  if (month) {
    args.push(month);
    where.push(`feast_month = $${args.length}`);
  }
  if (day) {
    args.push(day);
    where.push(`feast_day = $${args.length}`);
  }
  return { clause: where.length ? `WHERE ${where.join(' AND ')}` : '', args };
}

async function countSaints({ q, month, day }) {
  const { clause, args } = buildSaintsWhere(q, month, day);
  const result = await db.query(`SELECT count(*)::int AS n FROM saints ${clause}`, args);
  return result.rows[0]?.n || 0;
}

async function listSaints({ q, month, day, limit, offset }) {
  const { clause, args } = buildSaintsWhere(q, month, day);
  args.push(limit);
  const limIdx = args.length;
  args.push(offset);
  const offIdx = args.length;
  const result = await db.query(
    `
      SELECT source_saint_id, name_ko, name_latin, feast_month, feast_day,
             status, kind, region_ko, region_en, year_text, url, source, updated_at
      FROM saints
      ${clause}
      ORDER BY feast_month NULLS LAST, feast_day NULLS LAST, name_ko
      LIMIT $${limIdx} OFFSET $${offIdx}
    `,
    args,
  );
  return result.rows;
}

async function getSaint(id) {
  const result = await db.query('SELECT * FROM saints WHERE source_saint_id = $1', [id]);
  return result.rows[0] || null;
}

async function nextManualSaintId() {
  const result = await db.query(`
    SELECT COALESCE(MIN(source_saint_id), 10000000) - 1 AS id
    FROM saints
    WHERE source_saint_id BETWEEN 9000000 AND 9999999
  `);
  return Number(result.rows[0]?.id || 9999999);
}

async function nextManualSaintIds(count) {
  const firstId = await nextManualSaintId();
  return Array.from({ length: count }, (_, index) => firstId - index);
}

async function upsertSaintManual(s) {
  await db.query(
    `
      INSERT INTO saints (
        source_saint_id, name_ko, name_latin, feast_month, feast_day,
        status, kind, region_ko, region_en, year_text, detail_url, url, search_text, source, updated_at
      )
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,'manual', now())
      ON CONFLICT (source_saint_id) DO UPDATE SET
        name_ko = EXCLUDED.name_ko,
        name_latin = EXCLUDED.name_latin,
        feast_month = EXCLUDED.feast_month,
        feast_day = EXCLUDED.feast_day,
        status = EXCLUDED.status,
        kind = EXCLUDED.kind,
        region_ko = EXCLUDED.region_ko,
        region_en = EXCLUDED.region_en,
        year_text = EXCLUDED.year_text,
        detail_url = EXCLUDED.detail_url,
        url = EXCLUDED.url,
        search_text = EXCLUDED.search_text,
        source = 'manual',
        updated_at = now()
    `,
    [
      s.sourceSaintId,
      s.nameKo,
      s.nameLatin,
      s.feastMonth,
      s.feastDay,
      s.status,
      s.kind,
      s.regionKo,
      s.regionEn,
      s.yearText,
      s.detailUrl,
      s.url,
      s.searchText,
    ],
  );
}

function parseSaintAliases(value) {
  return [
    ...new Set(
      String(value || '')
        .split(/[\s,]+/)
        .map((s) => s.trim())
        .filter(Boolean),
    ),
  ];
}

function buildSaintSearchText(s, aliases) {
  return [
    s.nameKo,
    s.nameLatin,
    s.status,
    s.kind,
    s.regionKo,
    s.regionEn,
    s.yearText,
    ...aliases,
  ]
    .map((s) => String(s || '').trim())
    .filter(Boolean)
    .join(' ');
}

function normalizeSaintForm(form) {
  const sourceSaintId = Number(form.get('sourceSaintId'));
  if (!Number.isInteger(sourceSaintId) || sourceSaintId <= 0) {
    throw new Error('invalid_id');
  }
  const nameKo = String(form.get('nameKo') || '').trim();
  if (!nameKo) throw new Error('name_required');

  const monthRaw = String(form.get('feastMonth') || '').trim();
  const dayRaw = String(form.get('feastDay') || '').trim();
  const feastMonth = monthRaw === '' ? null : Number(monthRaw);
  const feastDay = dayRaw === '' ? null : Number(dayRaw);
  if (feastMonth !== null && (!Number.isInteger(feastMonth) || feastMonth < 1 || feastMonth > 12)) {
    throw new Error('invalid_month');
  }
  if (feastDay !== null && (!Number.isInteger(feastDay) || feastDay < 1 || feastDay > 31)) {
    throw new Error('invalid_day');
  }

  const saint = {
    sourceSaintId,
    isNew: String(form.get('formMode') || '') === 'new',
    nameKo,
    nameLatin: String(form.get('nameLatin') || '').trim(),
    feastMonth,
    feastDay,
    status: String(form.get('status') || '').trim(),
    kind: String(form.get('kind') || '').trim(),
    regionKo: String(form.get('regionKo') || '').trim(),
    regionEn: String(form.get('regionEn') || '').trim(),
    yearText: String(form.get('yearText') || '').trim(),
    detailUrl: String(form.get('detailUrl') || '').trim(),
    url: String(form.get('url') || '').trim(),
  };
  const aliases = parseSaintAliases(form.get('aliases'));
  return {
    ...saint,
    aliases,
    searchText: buildSaintSearchText(saint, aliases),
  };
}

function saintRows(rows) {
  if (rows.length === 0) {
    return '<div class="empty">성인 데이터가 없습니다. <code>scripts/import-saints.mjs</code>로 먼저 가져오세요.</div>';
  }
  const cells = rows
    .map((r) => {
      const feast = r.feast_month
        ? `${Number(r.feast_month)}월${r.feast_day ? `${Number(r.feast_day)}일` : ''}`
        : '-';
      const region = [r.region_ko, r.region_en].filter(Boolean).join(' / ');
      const manual =
        r.source === 'manual'
          ? ' <span style="color:var(--primary);font-size:12px;">· 수정됨</span>'
          : '';
      const url = r.url
        ? `<a class="button secondary" href="${escapeHtml(r.url)}" target="_blank" rel="noopener">열기</a>`
        : '';
      return `<tr>
        <td>${Number(r.source_saint_id)}</td>
        <td>${escapeHtml(r.name_ko)}${manual}</td>
        <td>${escapeHtml(r.name_latin)}</td>
        <td>${feast}</td>
        <td>${escapeHtml(r.status)}</td>
        <td>${escapeHtml(r.kind)}</td>
        <td>${escapeHtml(region)}</td>
        <td>${escapeHtml(r.year_text)}</td>
        <td>${url}</td>
        <td><a class="button secondary" href="${basePath}/saints/edit?id=${Number(r.source_saint_id)}">수정</a></td>
      </tr>`;
    })
    .join('');
  return `<table>
    <thead>
      <tr>
        <th>ID</th><th>이름</th><th>라틴/영문</th><th>축일</th><th>신분</th><th>등급</th><th>지역</th><th>연도</th><th>URL</th><th></th>
      </tr>
    </thead>
    <tbody>${cells}</tbody>
  </table>`;
}

function manualSaintTemplate(fallbackId) {
  return {
    source_saint_id: fallbackId,
    name_ko: '',
    name_latin: '',
    feast_month: null,
    feast_day: null,
    status: '',
    kind: '',
    region_ko: '',
    region_en: '',
    year_text: '',
    detail_url: '',
    url: '',
    source: 'manual',
  };
}

function saintEditForm(saint, aliases, inheritedAliases, options = {}) {
  const id = Number(saint.source_saint_id);
  const detail = saint.detail_url
    ? ` · <a href="${escapeHtml(saint.detail_url)}" target="_blank" rel="noopener">원본 보기</a>`
    : '';
  const aliasText = aliases.join(' ');
  const inherited = inheritedAliases.join(' ');
  const isNew = options.mode === 'new';
  const title = isNew ? '성인 수동 추가' : `${escapeHtml(saint.name_ko)} 수정`;
  const help = isNew
    ? '자동 임포트에 없거나 보완이 필요한 성인을 직접 추가합니다. 저장하면 출처가 <strong>manual</strong>로 보존됩니다.'
    : `원본 ID ${id}${detail} · 저장하면 출처가 <strong>manual</strong>로 바뀌어 재가져오기 시 덮어쓰지 않습니다.`;
  return `
    <form class="editor" method="post" action="${basePath}/saints/edit/commit">
      <input type="hidden" name="formMode" value="${isNew ? 'new' : 'edit'}">
      <div>
        <h2>${title}</h2>
        <div class="sub">${help}</div>
      </div>
      <label class="form-row">${isNew ? 'ID (자동 발급)' : 'ID'}<input name="sourceSaintId" class="wide" inputmode="numeric" value="${id}" readonly></label>
      <div class="form-grid">
        <label class="form-row">한글명<input name="nameKo" class="wide" value="${escapeHtml(saint.name_ko)}"></label>
        <label class="form-row">라틴/영문명<input name="nameLatin" class="wide" value="${escapeHtml(saint.name_latin)}"></label>
      </div>
      <div class="form-grid">
        <label class="form-row">축일 (월)<input name="feastMonth" inputmode="numeric" value="${saint.feast_month ?? ''}"></label>
        <label class="form-row">축일 (일)<input name="feastDay" inputmode="numeric" value="${saint.feast_day ?? ''}"></label>
      </div>
      <div class="form-grid">
        <label class="form-row">신분<input name="status" class="wide" value="${escapeHtml(saint.status)}"></label>
        <label class="form-row">등급<input name="kind" class="wide" value="${escapeHtml(saint.kind)}" placeholder="성인 / 복자 / 천사"></label>
      </div>
      <div class="form-grid">
        <label class="form-row">지역 (한글)<input name="regionKo" class="wide" value="${escapeHtml(saint.region_ko)}"></label>
        <label class="form-row">지역 (영문)<input name="regionEn" class="wide" value="${escapeHtml(saint.region_en)}"></label>
      </div>
      <label class="form-row">연도<input name="yearText" class="wide" value="${escapeHtml(saint.year_text)}"></label>
      <label class="form-row">원본 링크<input name="detailUrl" class="wide" value="${escapeHtml(saint.detail_url || '')}"></label>
      <label class="form-row">URL<input name="url" class="wide" value="${escapeHtml(saint.url || '')}"></label>
      ${inherited ? `<label class="form-row">공통 별칭<input class="wide" value="${escapeHtml(inherited)}" readonly></label>` : ''}
      <label class="form-row">개별 별칭<input name="aliases" class="wide" value="${escapeHtml(aliasText)}" placeholder="공백 또는 쉼표로 구분"></label>
      <div class="editor-actions">
        <a class="button secondary" href="${basePath}/saints">목록으로</a>
        <button type="submit">저장</button>
      </div>
    </form>`;
}

async function handleSaints(req, res, url) {
  const q = String(url.searchParams.get('q') || '').trim();
  const monthRaw = String(url.searchParams.get('month') || '').trim();
  const month =
    monthRaw && Number.isInteger(Number(monthRaw)) && Number(monthRaw) >= 1 && Number(monthRaw) <= 12
      ? Number(monthRaw)
      : null;
  const dayRaw = String(url.searchParams.get('day') || '').trim();
  const day =
    dayRaw && Number.isInteger(Number(dayRaw)) && Number(dayRaw) >= 1 && Number(dayRaw) <= 31
      ? Number(dayRaw)
      : null;
  const page = Math.max(1, Number(url.searchParams.get('page') || 1) || 1);

  const total = await countSaints({ q, month, day });
  const totalPages = Math.max(1, Math.ceil(total / SAINTS_PAGE_SIZE));
  const current = Math.min(page, totalPages);
  const rows = await listSaints({
    q,
    month,
    day,
    limit: SAINTS_PAGE_SIZE,
    offset: (current - 1) * SAINTS_PAGE_SIZE,
  });
  const message = url.searchParams.get('message');

  const pageLink = (p) => {
    const params = new URLSearchParams();
    if (q) params.set('q', q);
    if (month) params.set('month', String(month));
    if (day) params.set('day', String(day));
    params.set('page', String(p));
    return `${basePath}/saints?${params.toString()}`;
  };

  const toolbar = `
    <form class="toolbar" method="get" action="${basePath}/saints">
      <label>검색 <input name="q" value="${escapeHtml(q)}" placeholder="이름(한/영)"></label>
      <label>축일 월 <input name="month" inputmode="numeric" value="${month ?? ''}" style="width:64px"></label>
      <label>축일 일 <input name="day" inputmode="numeric" value="${day ?? ''}" style="width:64px"></label>
      <button type="submit">검색</button>
      ${q || month || day ? `<a class="button secondary" href="${basePath}/saints">초기화</a>` : ''}
      <a class="button secondary" href="${basePath}/saints/new">수동 추가</a>
      <a class="button secondary" href="${basePath}/saints/manual-import">JSON 가져오기</a>
    </form>`;
  const pager = `
    <div class="toolbar">
      <span class="sub">총 ${total}명 · ${current}/${totalPages}페이지</span>
      ${current > 1 ? `<a class="button secondary" href="${pageLink(current - 1)}">이전</a>` : ''}
      ${current < totalPages ? `<a class="button secondary" href="${pageLink(current + 1)}">다음</a>` : ''}
    </div>`;

  const content = `
    ${message ? `<div class="message">${escapeHtml(message)}</div>` : ''}
    ${toolbar}
    ${saintRows(rows)}
    ${pager}
  `;
  sendHtml(res, 200, layout('성인', content, 'saints'));
}

async function handleSaintNew(req, res, url) {
  const fallbackId = await nextManualSaintId();
  const saint = manualSaintTemplate(fallbackId);
  const aliasDoc = loadSaintAliasDoc();
  const aliases = [];
  const inheritedAliases = nameAliasesForSaint(aliasDoc, saint.name_ko, saint.name_latin);
  sendHtml(res, 200, layout('성인 수동 추가', saintEditForm(saint, aliases, inheritedAliases, { mode: 'new' }), 'saints'));
}

function saintManualImportSample() {
  return JSON.stringify(
    {
      saints: [
        {
          nameKo: '성인명',
          nameLatin: 'Latin Name',
          feastMonth: 1,
          feastDay: 1,
          status: '신분',
          kind: '성인',
          regionKo: '',
          regionEn: '',
          yearText: '',
          detailUrl: '',
          url: '',
          aliases: [],
        },
      ],
    },
    null,
    2,
  );
}

function normalizeManualSaintObject(raw, index) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    throw new Error(`${index + 1}번째 항목은 객체여야 합니다.`);
  }
  const rawSourceSaintId = raw.sourceSaintId ?? raw.source_saint_id;
  const sourceSaintId =
    rawSourceSaintId === undefined || rawSourceSaintId === null || rawSourceSaintId === ''
      ? null
      : Number(rawSourceSaintId);
  if (sourceSaintId !== null && (!Number.isInteger(sourceSaintId) || sourceSaintId <= 0)) {
    throw new Error(`${index + 1}번째 항목의 sourceSaintId가 올바르지 않습니다.`);
  }
  const nameKo = String(raw.nameKo ?? raw.name_ko ?? '').trim();
  if (!nameKo) throw new Error(`${index + 1}번째 항목의 nameKo는 필수입니다.`);

  const rawMonth = raw.feastMonth ?? raw.feast_month;
  const rawDay = raw.feastDay ?? raw.feast_day;
  const feastMonth = rawMonth === undefined || rawMonth === null || rawMonth === '' ? null : Number(rawMonth);
  const feastDay = rawDay === undefined || rawDay === null || rawDay === '' ? null : Number(rawDay);
  if (feastMonth !== null && (!Number.isInteger(feastMonth) || feastMonth < 1 || feastMonth > 12)) {
    throw new Error(`${index + 1}번째 항목의 feastMonth는 1-12 사이여야 합니다.`);
  }
  if (feastDay !== null && (!Number.isInteger(feastDay) || feastDay < 1 || feastDay > 31)) {
    throw new Error(`${index + 1}번째 항목의 feastDay는 1-31 사이여야 합니다.`);
  }

  const aliases = Array.isArray(raw.aliases)
    ? parseSaintAliases(raw.aliases.join(' '))
    : parseSaintAliases(raw.aliases || '');
  const saint = {
    sourceSaintId,
    isNew: true,
    nameKo,
    nameLatin: String(raw.nameLatin ?? raw.name_latin ?? '').trim(),
    feastMonth,
    feastDay,
    status: String(raw.status ?? '').trim(),
    kind: String(raw.kind ?? '').trim(),
    regionKo: String(raw.regionKo ?? raw.region_ko ?? '').trim(),
    regionEn: String(raw.regionEn ?? raw.region_en ?? '').trim(),
    yearText: String(raw.yearText ?? raw.year_text ?? '').trim(),
    detailUrl: String(raw.detailUrl ?? raw.detail_url ?? '').trim(),
    url: String(raw.url ?? '').trim(),
    aliases,
  };
  return buildManualSaintImportItem(saint);
}

function buildManualSaintImportItem(saint) {
  const aliasDoc = loadSaintAliasDoc();
  const inheritedAliases = nameAliasesForSaint(aliasDoc, saint.nameKo, saint.nameLatin);
  return {
    ...saint,
    searchText: buildSaintSearchText(saint, [...inheritedAliases, ...saint.aliases]),
  };
}

async function parseManualSaintsJson(payloadText) {
  let parsed;
  try {
    parsed = JSON.parse(payloadText);
  } catch (error) {
    throw new Error(`JSON 문법 오류: ${error.message}`);
  }
  const items = Array.isArray(parsed) ? parsed : parsed?.saints;
  if (!Array.isArray(items) || items.length === 0) {
    throw new Error('JSON은 배열이거나 { "saints": [...] } 형태여야 합니다.');
  }
  const saints = items.map((item, index) => normalizeManualSaintObject(item, index));
  const autoIds = await nextManualSaintIds(saints.filter((saint) => saint.sourceSaintId === null).length);
  let autoIndex = 0;
  const assignedSaints = saints.map((saint) => {
    if (saint.sourceSaintId !== null) return saint;
    return buildManualSaintImportItem({
      ...saint,
      sourceSaintId: autoIds[autoIndex++],
    });
  });
  const seen = new Set();
  for (const saint of assignedSaints) {
    if (seen.has(saint.sourceSaintId)) {
      throw new Error(`sourceSaintId ${saint.sourceSaintId}가 JSON 안에서 중복됩니다.`);
    }
    seen.add(saint.sourceSaintId);
  }
  return assignedSaints;
}

function saintManualImportPayload(saints) {
  return JSON.stringify(
    {
      saints: saints.map((saint) => ({
        sourceSaintId: saint.sourceSaintId,
        nameKo: saint.nameKo,
        nameLatin: saint.nameLatin,
        feastMonth: saint.feastMonth,
        feastDay: saint.feastDay,
        status: saint.status,
        kind: saint.kind,
        regionKo: saint.regionKo,
        regionEn: saint.regionEn,
        yearText: saint.yearText,
        detailUrl: saint.detailUrl,
        url: saint.url,
        aliases: saint.aliases,
      })),
    },
    null,
    2,
  );
}

async function existingSaintIdSet(ids) {
  if (ids.length === 0) return new Set();
  const result = await db.query(
    'SELECT source_saint_id FROM saints WHERE source_saint_id = ANY($1::int[])',
    [ids],
  );
  return new Set(result.rows.map((row) => Number(row.source_saint_id)));
}

function saintManualImportRows(saints, conflicts) {
  const cells = saints
    .map((s) => {
      const feast = s.feastMonth ? `${s.feastMonth}월${s.feastDay ? `${s.feastDay}일` : ''}` : '-';
      const state = conflicts.has(s.sourceSaintId) ? 'ID 중복' : '추가 가능';
      return `<tr>
        <td>${s.sourceSaintId}</td>
        <td>${escapeHtml(s.nameKo)}</td>
        <td>${escapeHtml(s.nameLatin)}</td>
        <td>${feast}</td>
        <td>${escapeHtml(s.status)}</td>
        <td>${escapeHtml(s.kind)}</td>
        <td>${escapeHtml([s.regionKo, s.regionEn].filter(Boolean).join(' / '))}</td>
        <td>${escapeHtml(s.yearText)}</td>
        <td>${escapeHtml(s.aliases.join(' '))}</td>
        <td>${state}</td>
      </tr>`;
    })
    .join('');
  return `<table>
    <thead>
      <tr>
        <th>ID</th><th>이름</th><th>라틴/영문</th><th>축일</th><th>신분</th><th>등급</th><th>지역</th><th>연도</th><th>개별 별칭</th><th>상태</th>
      </tr>
    </thead>
    <tbody>${cells}</tbody>
  </table>`;
}

function saintManualImportForm(payload = saintManualImportSample(), error = '') {
  return `
    ${error ? `<div class="empty">검증하지 못했습니다: ${escapeHtml(error)}</div>` : ''}
    <form class="editor" method="post" action="${basePath}/saints/manual-import/preview">
      <div>
        <h2>성인 JSON/파일 가져오기</h2>
        <div class="sub">정형 JSON을 붙여넣거나 .json 파일을 선택한 뒤 검증 화면을 거쳐 최종 저장합니다. 새 항목은 <strong>manual</strong> 출처로 저장됩니다.</div>
      </div>
      <label class="form-row">JSON 파일<input id="saint-json-file" type="file" accept="application/json,.json"></label>
      <textarea id="saint-json-payload" name="payload" spellcheck="false">${escapeHtml(payload)}</textarea>
      <div class="editor-actions">
        <a class="button secondary" href="${basePath}/saints">목록으로</a>
        <button type="submit">JSON 검증</button>
      </div>
    </form>
    <script>
      (() => {
        const fileInput = document.getElementById('saint-json-file');
        const payload = document.getElementById('saint-json-payload');
        if (!fileInput || !payload) return;
        fileInput.addEventListener('change', async () => {
          const file = fileInput.files && fileInput.files[0];
          if (!file) return;
          payload.value = await file.text();
        });
      })();
    </script>`;
}

async function handleSaintManualImport(req, res) {
  sendHtml(res, 200, layout('성인 JSON/파일 가져오기', saintManualImportForm(), 'saints'));
}

async function handleSaintManualImportPreview(req, res) {
  const form = await readForm(req);
  const payload = String(form.get('payload') || '').trim();
  let saints;
  try {
    saints = await parseManualSaintsJson(payload);
  } catch (error) {
    sendHtml(res, 400, layout('성인 JSON/파일 가져오기', saintManualImportForm(payload, error.message), 'saints'));
    return;
  }
  const conflicts = await existingSaintIdSet(saints.map((s) => s.sourceSaintId));
  const hasConflicts = conflicts.size > 0;
  const assignedPayload = saintManualImportPayload(saints);
  const content = `
    ${hasConflicts ? '<div class="empty">이미 같은 ID의 성인이 있습니다. 충돌을 해결한 뒤 다시 검증하세요.</div>' : '<div class="message">검증을 통과했습니다. 아래 항목을 확인한 뒤 최종 저장하세요.</div>'}
    ${saintManualImportRows(saints, conflicts)}
    <div class="toolbar">
      <form method="post" action="${basePath}/saints/manual-import/commit">
        <textarea class="hidden-payload" name="payload">${escapeHtml(assignedPayload)}</textarea>
        <button type="submit" ${hasConflicts ? 'disabled' : ''}>최종 저장</button>
      </form>
      <form method="post" action="${basePath}/saints/manual-import/preview">
        <textarea class="hidden-payload" name="payload">${escapeHtml(assignedPayload)}</textarea>
        <button class="secondary" type="submit">다시 검증</button>
      </form>
      <a class="button secondary" href="${basePath}/saints/manual-import">입력 화면으로</a>
    </div>`;
  sendHtml(res, 200, layout('성인 JSON 검증', content, 'saints'));
}

async function handleSaintManualImportCommit(req, res) {
  const form = await readForm(req);
  const payload = String(form.get('payload') || '').trim();
  let saints;
  try {
    saints = await parseManualSaintsJson(payload);
  } catch (error) {
    sendHtml(res, 400, layout('성인 JSON/파일 가져오기', saintManualImportForm(payload, error.message), 'saints'));
    return;
  }
  const conflicts = await existingSaintIdSet(saints.map((s) => s.sourceSaintId));
  if (conflicts.size > 0) {
    sendHtml(
      res,
      409,
      layout(
        '성인 JSON 검증',
        `<div class="empty">저장 직전에 ID 충돌이 발견되어 저장하지 않았습니다.</div>${saintManualImportRows(saints, conflicts)}`,
        'saints',
      ),
    );
    return;
  }

  try {
    for (const saint of saints) {
      saveSaintAliases(saint.sourceSaintId, saint.aliases);
      await upsertSaintManual(saint);
    }
  } catch (error) {
    sendHtml(
      res,
      500,
      layout('성인 JSON/파일 가져오기', `<div class="empty">저장하지 못했습니다: ${escapeHtml(error.message)}</div>`, 'saints'),
    );
    return;
  }

  await logAdminAction(req, 'saint_manual_import', 'saint', saints.map((s) => s.sourceSaintId).join(','), {
    count: saints.length,
    ids: saints.map((s) => s.sourceSaintId),
  });
  redirect(res, `${basePath}/saints?message=${encodeURIComponent(`${saints.length}개 성인을 추가했습니다.`)}`);
}

async function handleSaintEdit(req, res, url) {
  const id = Number(url.searchParams.get('id'));
  const saint = Number.isInteger(id) ? await getSaint(id) : null;
  if (!saint) {
    sendHtml(
      res,
      404,
      layout('성인', '<div class="empty">성인을 찾을 수 없습니다.</div>', 'saints'),
    );
    return;
  }
  const aliasDoc = loadSaintAliasDoc();
  const aliases = aliasDoc.byId[String(id)] || [];
  const inheritedAliases = nameAliasesForSaint(aliasDoc, saint.name_ko, saint.name_latin);
  sendHtml(res, 200, layout(`${saint.name_ko} 수정`, saintEditForm(saint, aliases, inheritedAliases), 'saints'));
}

async function handleSaintSave(req, res) {
  const form = await readForm(req);
  let saint;
  try {
    saint = normalizeSaintForm(form);
  } catch (error) {
    sendHtml(
      res,
      400,
      layout(
        '성인',
        `<div class="empty">저장하지 못했습니다. 이름은 필수이고, 축일 월(1-12)/일(1-31)은 숫자여야 합니다.</div>
        <div class="toolbar"><a class="button secondary" href="${basePath}/saints">목록으로 돌아가기</a></div>`,
        'saints',
      ),
    );
    return;
  }

  const aliasDoc = loadSaintAliasDoc();
  const inheritedAliases = nameAliasesForSaint(aliasDoc, saint.nameKo, saint.nameLatin);
  saint.searchText = buildSaintSearchText(saint, [...inheritedAliases, ...saint.aliases]);

  if (saint.isNew && (await getSaint(saint.sourceSaintId))) {
    sendHtml(
      res,
      409,
      layout(
        '성인',
        `<div class="empty">이미 같은 ID의 성인이 있습니다. 다른 ID를 사용하거나 기존 항목을 수정하세요.</div>
        <div class="toolbar"><a class="button secondary" href="${basePath}/saints/edit?id=${saint.sourceSaintId}">기존 항목 수정</a><a class="button secondary" href="${basePath}/saints/new">새 ID로 추가</a></div>`,
        'saints',
      ),
    );
    return;
  }

  try {
    saveSaintAliases(saint.sourceSaintId, saint.aliases);
  } catch (error) {
    sendHtml(
      res,
      500,
      layout(
        '성인',
        `<div class="empty">별칭 파일을 저장하지 못했습니다. <code>${escapeHtml(saintsAliasFile)}</code> 권한을 확인하세요.</div>
        <div class="toolbar"><a class="button secondary" href="${basePath}/saints/edit?id=${saint.sourceSaintId}">수정 화면으로 돌아가기</a></div>`,
        'saints',
      ),
    );
    return;
  }
  await upsertSaintManual(saint);
  await logAdminAction(req, 'saint_update', 'saint', String(saint.sourceSaintId), {
    name_ko: saint.nameKo,
    aliases: saint.aliases,
  });
  redirect(res, `${basePath}/saints?message=${encodeURIComponent('성인 정보를 저장했습니다.')}`);
}

async function handleRequest(req, res) {
  const url = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);
  if (url.pathname === '/health' && req.method === 'GET') {
    await db.query('SELECT 1');
    sendJson(res, 200, { ok: true, service: 'catholic-calendar-backoffice' });
    return;
  }

  if (!requireAuth(req, res)) return;

  if ((url.pathname === '/' || url.pathname === basePath) && req.method === 'GET') {
    await handleIndex(req, res, url);
    return;
  }

  if (url.pathname === `${basePath}/calendar/edit` && req.method === 'GET') {
    await handleEdit(req, res, url);
    return;
  }

  if (url.pathname === `${basePath}/calendar/revisions` && req.method === 'GET') {
    await handleRevisions(req, res, url);
    return;
  }

  if (url.pathname === `${basePath}/calendar/revisions/view` && req.method === 'GET') {
    await handleRevisionView(req, res, url);
    return;
  }

  if (url.pathname === `${basePath}/audit-logs` && req.method === 'GET') {
    await handleAuditLogs(req, res);
    return;
  }

  if (url.pathname === `${basePath}/app-update-policy` && req.method === 'GET') {
    await handleAppUpdatePolicy(req, res, url);
    return;
  }

  if (url.pathname === `${basePath}/app-update-policy/save` && req.method === 'POST') {
    await handleAppUpdatePolicySave(req, res);
    return;
  }

  if (url.pathname === `${basePath}/saints` && req.method === 'GET') {
    await handleSaints(req, res, url);
    return;
  }

  if (url.pathname === `${basePath}/saints/new` && req.method === 'GET') {
    await handleSaintNew(req, res, url);
    return;
  }

  if (url.pathname === `${basePath}/saints/manual-import` && req.method === 'GET') {
    await handleSaintManualImport(req, res);
    return;
  }

  if (url.pathname === `${basePath}/saints/manual-import/preview` && req.method === 'POST') {
    await handleSaintManualImportPreview(req, res);
    return;
  }

  if (url.pathname === `${basePath}/saints/manual-import/commit` && req.method === 'POST') {
    await handleSaintManualImportCommit(req, res);
    return;
  }

  if (url.pathname === `${basePath}/saints/edit` && req.method === 'GET') {
    await handleSaintEdit(req, res, url);
    return;
  }

  if (url.pathname === `${basePath}/saints/edit/commit` && req.method === 'POST') {
    await handleSaintSave(req, res);
    return;
  }

  if (url.pathname === `${basePath}/calendar/delete` && req.method === 'POST') {
    await handlePost(req, res, 'delete');
    return;
  }

  if (url.pathname === `${basePath}/calendar/revisions/restore` && req.method === 'POST') {
    await handleRevisionRestore(req, res);
    return;
  }

  if (url.pathname === `${basePath}/calendar/edit/preview` && req.method === 'POST') {
    await handleEditPreview(req, res);
    return;
  }

  if (url.pathname === `${basePath}/calendar/edit/restore` && req.method === 'POST') {
    await handleEditRestore(req, res);
    return;
  }

  if (url.pathname === `${basePath}/calendar/edit/commit` && req.method === 'POST') {
    await handlePost(req, res, 'edit');
    return;
  }

  if (url.pathname === `${basePath}/calendar/refresh` && req.method === 'POST') {
    await handlePost(req, res, 'refresh');
    return;
  }

  sendJson(res, 404, { error: 'not_found' });
}

const server = http.createServer((req, res) => {
  handleRequest(req, res).catch((error) => {
    console.error('Unhandled backoffice error', error);
    sendHtml(
      res,
      500,
      layout(
        'KCC Backoffice Error',
        `<div class="empty">오류가 발생했습니다: ${escapeHtml(error.message)}</div>`,
      ),
    );
  });
});

ensureSchema()
  .then(() => {
    server.listen(port, host, () => {
      console.log(`catholic-calendar backoffice listening on ${host}:${port}`);
    });
  })
  .catch((error) => {
    console.error('Failed to initialize backoffice storage', error);
    process.exit(1);
  });

function shutdown(signal) {
  console.log(`Received ${signal}, shutting down`);
  server.close(() => {
    db.end()
      .catch((error) => {
        console.error('Failed to close database pool', error);
      })
      .finally(() => {
        process.exit(0);
      });
  });
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
