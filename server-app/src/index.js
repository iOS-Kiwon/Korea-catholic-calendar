import http from 'node:http';
import fs from 'node:fs';
import pg from 'pg';

const port = Number(process.env.API_PORT || 8080);
const host = process.env.API_HOST || '0.0.0.0';
const appEnv = process.env.APP_ENV || 'development';
const databaseUrl = process.env.DATABASE_URL;
const postgresHost = process.env.POSTGRES_HOST || 'db';
const postgresPort = Number(process.env.POSTGRES_PORT || 5432);
const postgresDb = process.env.POSTGRES_DB;
const postgresUser = process.env.POSTGRES_USER;
const postgresPassword = process.env.POSTGRES_PASSWORD;
const workerBaseUrl =
  process.env.CLOUDFLARE_WORKER_BASE_URL ||
  'https://catholic-calendar.sidore.workers.dev';
const apiPrefix = '/kcc/v1';
const saintsAliasFile =
  process.env.SAINTS_ALIAS_FILE || '/app/saint-aliases.json';

const startedAt = new Date();
const db = createDbPool();

function createDbPool() {
  if (postgresDb && postgresUser && postgresPassword) {
    return new pg.Pool({
      host: postgresHost,
      port: postgresPort,
      database: postgresDb,
      user: postgresUser,
      password: postgresPassword,
    });
  }

  if (databaseUrl) {
    return new pg.Pool({ connectionString: databaseUrl });
  }

  return null;
}

function sendJson(res, status, body, headers = {}) {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    ...headers,
  });
  res.end(payload);
}

function sendText(res, status, body) {
  res.writeHead(status, {
    'content-type': 'text/plain; charset=utf-8',
    'cache-control': 'no-store',
  });
  res.end(body);
}

function calendarUrl(year, month) {
  return `${workerBaseUrl.replace(/\/+$/, '')}/v1/calendar/${year}/${month}`;
}

function loadSaintAliases() {
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

function normalizePlatform(value) {
  const platform = String(value || '').trim().toLowerCase();
  if (platform !== 'ios' && platform !== 'android') return null;
  return platform;
}

function isSemanticVersion(value) {
  return /^\d+\.\d+\.\d+$/.test(String(value || '').trim());
}

function compareSemanticVersions(left, right) {
  const leftParts = left.split('.').map(Number);
  const rightParts = right.split('.').map(Number);
  for (let index = 0; index < 3; index += 1) {
    if (leftParts[index] < rightParts[index]) return -1;
    if (leftParts[index] > rightParts[index]) return 1;
  }
  return 0;
}

function platformUpdatePolicy(policy, platform) {
  if (platform === 'ios') {
    return {
      updateMode: policy.ios_update_mode || policy.update_mode || 'none',
      updateVersion: policy.ios_update_version || '',
    };
  }
  if (platform === 'android') {
    return {
      updateMode: policy.android_update_mode || policy.update_mode || 'none',
      updateVersion: policy.android_update_version || '',
    };
  }
  return { updateMode: 'none', updateVersion: '' };
}

async function ensureSchema() {
  if (!db) {
    console.warn('Database settings are not set. Calendar DB cache is disabled.');
    return;
  }

  await db.query(`
    CREATE TABLE IF NOT EXISTS calendar_months (
      year integer NOT NULL,
      month integer NOT NULL,
      available boolean NOT NULL DEFAULT true,
      source text NOT NULL,
      payload_json jsonb NOT NULL,
      fetched_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now(),
      PRIMARY KEY (year, month),
      CHECK (year >= 1900 AND year <= 2200),
      CHECK (month >= 1 AND month <= 12)
    )
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
    ALTER TABLE saints ADD COLUMN IF NOT EXISTS url text NOT NULL DEFAULT ''
  `);

  await db.query(`
    ALTER TABLE saints ADD COLUMN IF NOT EXISTS search_text text NOT NULL DEFAULT ''
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

  const saintAliases = loadSaintAliases();
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

  await db.query(`
    CREATE INDEX IF NOT EXISTS saints_search_text_idx ON saints (search_text)
  `);
}

async function initializeStorage() {
  const maxAttempts = 30;
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      await ensureSchema();
      return;
    } catch (error) {
      if (attempt === maxAttempts) {
        throw error;
      }
      console.warn(`Waiting for database... ${attempt}/${maxAttempts}`);
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }
  }
}

async function findCachedCalendar(year, month) {
  if (!db) return null;

  const result = await db.query(
    `
      SELECT available, source, payload_json, fetched_at, updated_at
      FROM calendar_months
      WHERE year = $1 AND month = $2
    `,
    [year, month],
  );

  return result.rows[0] || null;
}

async function saveCachedCalendar(year, month, payload, source) {
  if (!db) return;

  await db.query(
    `
      INSERT INTO calendar_months (
        year, month, available, source, payload_json, fetched_at, updated_at
      )
      VALUES ($1, $2, $3, $4, $5::jsonb, now(), now())
      ON CONFLICT (year, month)
      DO UPDATE SET
        available = EXCLUDED.available,
        source = EXCLUDED.source,
        payload_json = EXCLUDED.payload_json,
        fetched_at = EXCLUDED.fetched_at,
        updated_at = now()
    `,
    [year, month, payload.available !== false, source, JSON.stringify(payload)],
  );
}

async function findAppUpdatePolicy() {
  if (!db) return null;

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

  return result.rows[0] || null;
}

function defaultAppUpdatePolicy() {
  return {
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
  };
}

function parseCalendarPath(pathname) {
  const match = pathname.match(/^\/kcc\/v1\/calendar\/(\d{4})\/(\d{1,2})$/);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  if (!Number.isInteger(year) || !Number.isInteger(month)) return null;
  if (year < 1900 || year > 2200 || month < 1 || month > 12) return null;
  return { year, month };
}

async function handleCalendar(req, res, year, month) {
  if (req.method !== 'GET') {
    sendJson(res, 405, { error: 'method_not_allowed' }, { allow: 'GET' });
    return;
  }

  const cached = await findCachedCalendar(year, month);
  if (cached) {
    sendJson(res, 200, cached.payload_json, {
      'x-calendar-source': 'server-db',
      'x-calendar-cache': 'hit',
    });
    return;
  }

  const upstream = calendarUrl(year, month);
  try {
    const response = await fetch(upstream, {
      headers: {
        accept: 'application/json',
        'user-agent': 'catholic-calendar-self-hosted-server/0.1.0',
      },
      signal: AbortSignal.timeout(8000),
    });
    const text = await response.text();
    const contentType =
      response.headers.get('content-type') || 'application/json; charset=utf-8';

    if (response.ok && contentType.includes('application/json')) {
      try {
        await saveCachedCalendar(
          year,
          month,
          JSON.parse(text),
          'cloudflare-worker',
        );
      } catch (error) {
        console.error('Failed to save calendar cache', error);
      }
    }

    res.writeHead(response.status, {
      'content-type': contentType,
      'cache-control': 'no-store',
      'x-calendar-source': 'cloudflare-worker',
      'x-calendar-cache': 'miss',
    });
    res.end(text);
  } catch (error) {
    sendJson(res, 200, {
      year,
      month,
      available: false,
      error: 'upstream_unavailable',
    });
  }
}

async function handleAppVersion(req, res, url) {
  if (req.method !== 'GET') {
    sendJson(res, 405, { error: 'method_not_allowed' }, { allow: 'GET' });
    return;
  }

  const platform = normalizePlatform(url.searchParams.get('platform'));
  const currentVersion = String(
    url.searchParams.get('version') || url.searchParams.get('appVersion') || '',
  ).trim();

  if (!platform) {
    sendJson(res, 400, { error: 'invalid_platform' });
    return;
  }

  if (!isSemanticVersion(currentVersion)) {
    sendJson(res, 400, { error: 'invalid_version' });
    return;
  }

  const policy = (await findAppUpdatePolicy()) || defaultAppUpdatePolicy();
  const platformPolicy = platformUpdatePolicy(policy, platform);
  const updateVersion = platformPolicy.updateVersion;
  const versionApplies =
    isSemanticVersion(updateVersion) &&
    compareSemanticVersions(currentVersion, updateVersion) < 0;
  const updateMode = versionApplies ? platformPolicy.updateMode : 'none';
  const forceUpdate = updateMode === 'force';
  const updateRecommended = updateMode === 'recommended';
  const dialog = forceUpdate
    ? {
        type: 'forceUpdate',
        title: policy.force_update_title,
        message: policy.force_update_message,
        actions: ['update'],
      }
    : updateRecommended
      ? {
          type: 'recommendedUpdate',
          title: policy.recommended_update_title,
          message: policy.update_message,
          actions: ['later', 'update'],
        }
      : { type: 'none', title: '', message: '', actions: [] };

  sendJson(res, 200, {
    platform,
    currentVersion,
    updateVersion,
    forceUpdate,
    updateRecommended,
    updateMode,
    title: dialog.title,
    message: dialog.message,
    dialog,
    updatedAt: policy.updated_at ? new Date(policy.updated_at).toISOString() : null,
  });
}

async function handleSaints(req, res, url) {
  if (req.method !== 'GET') {
    sendJson(res, 405, { error: 'method_not_allowed' }, { allow: 'GET' });
    return;
  }
  if (!db) {
    sendJson(res, 503, { error: 'database_unavailable' });
    return;
  }

  const q = String(url.searchParams.get('q') || '').trim();
  const month = Number(url.searchParams.get('month') || 0);
  const day = Number(url.searchParams.get('day') || 0);
  const limit = Math.min(50, Math.max(1, Number(url.searchParams.get('limit') || 30)));
  const where = [];
  const args = [];
  if (q) {
    args.push(`%${q}%`);
    where.push(`(name_ko ILIKE $${args.length} OR name_latin ILIKE $${args.length} OR search_text ILIKE $${args.length})`);
  }
  if (Number.isInteger(month) && month >= 1 && month <= 12) {
    args.push(month);
    where.push(`feast_month = $${args.length}`);
  }
  if (Number.isInteger(day) && day >= 1 && day <= 31) {
    args.push(day);
    where.push(`feast_day = $${args.length}`);
  }
  args.push(limit);
  const limitIndex = args.length;

  const result = await db.query(
    `
      SELECT source_saint_id, name_ko, name_latin, feast_month, feast_day,
             status, kind, region_ko, region_en, year_text, url
      FROM saints
      ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
      ORDER BY feast_month NULLS LAST, feast_day NULLS LAST, name_ko
      LIMIT $${limitIndex}
    `,
    args,
  );

  sendJson(res, 200, {
    items: result.rows.map((r) => ({
      id: Number(r.source_saint_id),
      nameKo: r.name_ko,
      nameLatin: r.name_latin,
      feastMonth: r.feast_month == null ? null : Number(r.feast_month),
      feastDay: r.feast_day == null ? null : Number(r.feast_day),
      status: r.status,
      kind: r.kind,
      regionKo: r.region_ko,
      regionEn: r.region_en,
      yearText: r.year_text,
      url: r.url,
    })),
  });
}

async function handleRequest(req, res) {
  const url = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);

  if (url.pathname === '/' && req.method === 'GET') {
    sendText(res, 200, 'catholic-calendar self-hosted server ok');
    return;
  }

  if (
    (url.pathname === `${apiPrefix}/health` || url.pathname === '/health') &&
    req.method === 'GET'
  ) {
    sendJson(res, 200, {
      ok: true,
      service: 'catholic-calendar-server-app',
      env: appEnv,
      apiPrefix,
      startedAt: startedAt.toISOString(),
      uptimeSeconds: Math.floor(process.uptime()),
    });
    return;
  }

  const calendar = parseCalendarPath(url.pathname);
  if (calendar) {
    await handleCalendar(req, res, calendar.year, calendar.month);
    return;
  }

  if (url.pathname === `${apiPrefix}/app/version`) {
    await handleAppVersion(req, res, url);
    return;
  }

  if (url.pathname === `${apiPrefix}/saints`) {
    await handleSaints(req, res, url);
    return;
  }

  sendJson(res, 404, { error: 'not_found' });
}

const server = http.createServer((req, res) => {
  handleRequest(req, res).catch((error) => {
    console.error('Unhandled request error', error);
    sendJson(res, 500, { error: 'internal_server_error' });
  });
});

initializeStorage()
  .then(() => {
    server.listen(port, host, () => {
      console.log(`catholic-calendar server listening on ${host}:${port}`);
    });
  })
  .catch((error) => {
    console.error('Failed to initialize server storage', error);
    process.exit(1);
  });

function shutdown(signal) {
  console.log(`Received ${signal}, shutting down`);
  server.close(() => {
    if (!db) {
      process.exit(0);
      return;
    }

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
