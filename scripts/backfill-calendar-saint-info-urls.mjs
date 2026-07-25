#!/usr/bin/env node

// Backfills calendar_months.payload_json.days[].saintInfoUrl by matching each
// single-saint liturgical title against saints on the same feast month/day.
//
// Usage:
//   node --env-file=../ops/.env backfill-calendar-saint-info-urls.mjs --dry
//   node --env-file=../ops/.env backfill-calendar-saint-info-urls.mjs

import pg from 'pg';

import {
  enrichCalendarPayloadWithSaintUrls,
} from '../server-app/src/saint-calendar-enrichment.js';

const databaseUrl = process.env.DATABASE_URL;
const postgresHost = process.env.POSTGRES_HOST || 'db';
const postgresPort = Number(process.env.POSTGRES_PORT || 5432);
const postgresDb = process.env.POSTGRES_DB;
const postgresUser = process.env.POSTGRES_USER;
const postgresPassword = process.env.POSTGRES_PASSWORD;
const dryRun = process.argv.includes('--dry');

const db = createDbPool();
if (!db) {
  console.error('Database settings are not set.');
  process.exit(1);
}

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

function safeHttpUrl(value) {
  try {
    const url = new URL(String(value || '').trim());
    if (url.protocol !== 'https:' && url.protocol !== 'http:') return '';
    return url.toString();
  } catch {
    return '';
  }
}

async function findUniqueSaintInfoUrlForCalendarDay({ query, month, day }) {
  const result = await db.query(
    `
      SELECT url
      FROM saints
      WHERE feast_month = $1
        AND feast_day = $2
        AND url <> ''
        AND (
          name_ko ILIKE $3 OR
          name_latin ILIKE $3 OR
          search_text ILIKE $3
        )
      ORDER BY name_ko
      LIMIT 2
    `,
    [month, day, `%${query}%`],
  );

  if (result.rows.length !== 1) return '';
  return safeHttpUrl(result.rows[0].url);
}

try {
  const result = await db.query(`
    SELECT year, month, source, payload_json
    FROM calendar_months
    ORDER BY year, month
  `);

  let changedMonths = 0;
  let changedDays = 0;

  for (const row of result.rows) {
    const before = countSaintInfoUrls(row.payload_json);
    const enriched = await enrichCalendarPayloadWithSaintUrls(
      row.payload_json,
      findUniqueSaintInfoUrlForCalendarDay,
    );
    if (!enriched.changed) continue;

    const after = countSaintInfoUrls(enriched.payload);
    changedMonths += 1;
    changedDays += Math.max(0, after - before);

    if (!dryRun) {
      await db.query(
        `
          UPDATE calendar_months
          SET payload_json = $3::jsonb, updated_at = now()
          WHERE year = $1 AND month = $2
        `,
        [row.year, row.month, JSON.stringify(enriched.payload)],
      );
    }

    console.log(
      `${dryRun ? '[dry] ' : ''}${row.year}-${String(row.month).padStart(2, '0')}: ${after - before} URLs added`,
    );
  }

  console.log(
    `${dryRun ? '[dry] ' : ''}done: ${changedMonths} months, ${changedDays} day URLs added`,
  );
} finally {
  await db.end();
}

function countSaintInfoUrls(payload) {
  if (!payload || !Array.isArray(payload.days)) return 0;
  return payload.days.filter((day) => day && day.saintInfoUrl).length;
}
