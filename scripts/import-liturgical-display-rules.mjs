#!/usr/bin/env node

// Imports manually confirmed liturgical display decisions from
// assets/calendar/liturgical_display_YYYY.json into DB-backed reusable rules.
//
// Usage:
//   node --env-file=../ops/.env import-liturgical-display-rules.mjs --year 2026 --dry
//   node --env-file=../ops/.env import-liturgical-display-rules.mjs --year 2026

import fs from 'node:fs/promises';

import {
  liturgicalDisplayTitleKey,
} from '../server-app/src/liturgical-display-enrichment.js';

const args = parseArgs(process.argv.slice(2));
const year = Number(args.year || 2026);
const datasetPath =
  args.dataset || `../assets/calendar/liturgical_display_${year}.json`;
const dryRun = Boolean(args.dry);

const databaseUrl = process.env.DATABASE_URL;
const postgresHost = process.env.POSTGRES_HOST || 'db';
const postgresPort = Number(process.env.POSTGRES_PORT || 5432);
const postgresDb = process.env.POSTGRES_DB;
const postgresUser = process.env.POSTGRES_USER;
const postgresPassword = process.env.POSTGRES_PASSWORD;

const pg = dryRun ? null : await import('pg');
const db = createDbPool();
if (!db && !dryRun) {
  console.error('Database settings are not set.');
  process.exit(1);
}

const dataset = JSON.parse(await fs.readFile(new URL(datasetPath, import.meta.url), 'utf8'));
const decisions = (dataset.entries || [])
  .filter((entry) => entry.matchStatus === 'manualConfirmed')
  .filter((entry) => entry.displayType === 'liturgy' || entry.displayType === 'saintFeast');

try {
  if (!dryRun) await ensureSchema();

  let imported = 0;
  const seen = new Set();
  for (const entry of decisions) {
    const source = entry.source === 'alternative' ? 'alternative' : 'primary';
    const title = normalizeText(entry.title);
    const titleKey = liturgicalDisplayTitleKey(title);
    const displayType = entry.displayType;
    const key = [source, titleKey].join('\u0000');
    if (!title || seen.has(key)) continue;
    seen.add(key);

    if (!dryRun) {
      await db.query(
        `
          INSERT INTO liturgical_display_rules (
            source, title, title_key, display_type, note, enabled, created_at, updated_at
          )
          VALUES ($1, $2, $3, $4, $5, true, now(), now())
          ON CONFLICT (source, title_key) WHERE enabled
          DO UPDATE SET
            title = EXCLUDED.title,
            display_type = EXCLUDED.display_type,
            note = EXCLUDED.note,
            updated_at = now()
        `,
        [
          source,
          title,
          titleKey,
          displayType,
          `imported from liturgical_display_${year}.json manual review`,
        ],
      );
    }
    imported += 1;
  }

  console.log(
    `${dryRun ? '[dry] ' : ''}imported ${imported} display rules from ${datasetPath}`,
  );
} finally {
  await db?.end();
}

async function ensureSchema() {
  await db.query(`
    CREATE TABLE IF NOT EXISTS liturgical_display_rules (
      id bigserial PRIMARY KEY,
      source text NOT NULL DEFAULT 'any',
      title text NOT NULL,
      title_key text NOT NULL,
      display_type text NOT NULL,
      note text NOT NULL DEFAULT '',
      enabled boolean NOT NULL DEFAULT true,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now(),
      CHECK (source IN ('any', 'primary', 'alternative')),
      CHECK (display_type IN ('liturgy', 'saintFeast'))
    )
  `);

  await db.query(`
    CREATE UNIQUE INDEX IF NOT EXISTS liturgical_display_rules_source_title_key_idx
    ON liturgical_display_rules (source, title_key)
    WHERE enabled
  `);
}

function createDbPool() {
  if (dryRun) return null;

  if (postgresDb && postgresUser && postgresPassword) {
    return new pg.default.Pool({
      host: postgresHost,
      port: postgresPort,
      database: postgresDb,
      user: postgresUser,
      password: postgresPassword,
    });
  }

  if (databaseUrl) {
    return new pg.default.Pool({ connectionString: databaseUrl });
  }

  return null;
}

function parseArgs(argv) {
  const parsed = {};
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (!arg.startsWith('--')) continue;
    const key = arg.slice(2);
    const next = argv[index + 1];
    if (!next || next.startsWith('--')) {
      parsed[key] = true;
    } else {
      parsed[key] = next;
      index += 1;
    }
  }
  return parsed;
}

function normalizeText(value) {
  return String(value || '')
    .replace(/\u00a0/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}
