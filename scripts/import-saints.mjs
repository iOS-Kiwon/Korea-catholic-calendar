#!/usr/bin/env node
// 성인(聖人) 목록 임포터
//
// maria.catholic.or.kr(가톨릭 굿뉴스) 성인 목록(list.asp)을 페이지 단위로 받아
// 파싱한 뒤 Postgres `saints` 테이블에 upsert 한다. 백오피스에서 수동 수정한 행
// (source='manual')은 재임포트해도 덮어쓰지 않는다.
//
// 사전 준비 (한 번):
//   cd scripts && npm install
//
// 실행 (Mac mini 호스트, ops/.env 재사용):
//   node --env-file=../ops/.env import-saints.mjs                 # 전체(7페이지)
//   node --env-file=../ops/.env import-saints.mjs --psize 20 --page 1   # 소량 검증
//   node --env-file=../ops/.env import-saints.mjs --dry --psize 5       # 파싱만(DB 미기록)
//
// 주의: 운영자가 자동 수집을 원치 않을 수 있으므로 약관/허가를 먼저 확인한다.
//   일반 브라우저 UA를 쓰고(AI 봇 UA 금지), 페이지 사이에 딜레이를 둔다.

// pg는 DB 기록 시에만 필요하므로 지연 import (--dry 는 pg 설치 없이 파싱 검증 가능).

const BASE = process.env.SAINTS_SOURCE_BASE_URL || 'https://maria.catholic.or.kr';
const LIST_PATH = '/sa_ho/list/list.asp';
const PAGE_DELAY_MS = Number(process.env.SAINTS_PAGE_DELAY_MS || 1500);

// 목록 경로는 robots.txt에서 일반 UA에 대해 막혀있지 않다. AI 브랜드 UA는 쓰지 않는다.
const HEADERS = {
  accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  'accept-language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
  referer: `${BASE}/sa_ho/list/list.asp`,
  'user-agent':
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ' +
    '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
};

const KIND_LABELS = { 성: '성인', 복: '복자', 천: '천사', 가: '가경자' };

function parseArgs(argv) {
  const args = { psize: 1000, page: null, dry: false };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--dry') args.dry = true;
    else if (a === '--psize') args.psize = parseInt(argv[++i], 10) || 1000;
    else if (a === '--page') args.page = parseInt(argv[++i], 10) || 1;
  }
  return args;
}

function listUrl(page, psize) {
  const q = new URLSearchParams({
    menugubun: 'saint',
    Orggubun: '101',
    ctxtChecked: 'Checked',
    curpage: String(page),
    ctxtOrder: 'name1,galadaym,galadayd',
    PSIZE: String(psize),
  });
  return `${BASE}${LIST_PATH}?${q.toString()}`;
}

const _entities = { '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#39;': "'", '&nbsp;': ' ' };
function clean(s) {
  if (!s) return '';
  return s
    .replace(/<[^>]*>/g, ' ')
    .replace(/&amp;|&lt;|&gt;|&quot;|&#39;|&nbsp;/g, (m) => _entities[m] || ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function parseRows(html) {
  const rows = [];
  const trRe = /<tr\b[^>]*>([\s\S]*?)<\/tr>/gi;
  let m;
  while ((m = trRe.exec(html))) {
    const tr = m[1];
    const idM = /fnGoSaint\((\d+)\)/.exec(tr);
    if (!idM) continue;
    const id = parseInt(idM[1], 10);

    // 이름: fnGoSaint 앵커 텍스트 2개 (한글명, 라틴/영문명) 순서대로
    const names = [...tr.matchAll(/<a[^>]*fnGoSaint\(\d+\)[^>]*>([\s\S]*?)<\/a>/gi)].map((x) =>
      clean(x[1]),
    );
    const nameKo = names[0] || '';
    const nameLatin = names[1] || '';

    // 등급(성인/복자/천사): thum_name 앵커 텍스트
    const gradeM = /class="thum_name"[^>]*>[\s\S]*?<a[^>]*>([\s\S]*?)<\/a>/i.exec(tr);
    const gradeRaw = gradeM ? clean(gradeM[1]) : '';
    const kind = KIND_LABELS[gradeRaw] || gradeRaw;

    // 축일: fnSearch22(월, 일)
    const feastM = /fnSearch22\((\d+)\s*,\s*(\d+)\)/.exec(tr);
    const feastMonth = feastM ? parseInt(feastM[1], 10) : null;
    const feastDay = feastM ? parseInt(feastM[2], 10) : null;

    // 신분: fnSearch3('왕'), fnSearch3('순교자') ...
    const status = [...tr.matchAll(/fnSearch3\('([^']*)'\)/g)].map((x) => clean(x[1])).join(', ');

    // 지역: fnSearch5('덴마크(Denmark)')
    let regionKo = '';
    let regionEn = '';
    const regionM = /fnSearch5\('([^']*)'\)/.exec(tr);
    if (regionM) {
      const raw = clean(regionM[1]);
      const pm = /^(.*?)\((.*)\)\s*$/.exec(raw);
      if (pm) {
        regionKo = pm[1].trim();
        regionEn = pm[2].trim();
      } else {
        regionKo = raw;
      }
    }

    // 연도: 마지막 <td> 텍스트 (+1086년 / 1613-1670년)
    const tds = [...tr.matchAll(/<td\b[^>]*>([\s\S]*?)<\/td>/gi)].map((x) => clean(x[1]));
    const yearText = tds.length ? tds[tds.length - 1] : '';

    rows.push({
      id,
      nameKo,
      nameLatin,
      feastMonth,
      feastDay,
      status,
      kind,
      regionKo,
      regionEn,
      yearText,
      detailUrl: `${BASE}/sa_ho/list/view.asp?menugubun=saint&Orggubun=101&ctxtSaintId=${id}`,
    });
  }
  return rows;
}

function parseTotal(html) {
  const m = /총\s*([\d,]+)\s*명/.exec(clean(html));
  return m ? parseInt(m[1].replace(/,/g, ''), 10) : null;
}

async function fetchPage(page, psize) {
  const res = await fetch(listUrl(page, psize), { headers: HEADERS });
  if (!res.ok) throw new Error(`HTTP ${res.status} on page ${page}`);
  return res.text();
}

async function createPool() {
  const pg = (await import('pg')).default;
  const { DATABASE_URL, POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_PORT } = process.env;
  // CLI는 Mac mini 호스트에서 실행되므로 docker 내부 호스트명 'db'는 노출 포트(127.0.0.1)로 매핑.
  const rawHost = process.env.SAINTS_DB_HOST || process.env.POSTGRES_HOST;
  const host = !rawHost || rawHost === 'db' ? '127.0.0.1' : rawHost;
  if (POSTGRES_DB && POSTGRES_USER && POSTGRES_PASSWORD) {
    return new pg.Pool({
      host,
      port: Number(POSTGRES_PORT || 5432),
      database: POSTGRES_DB,
      user: POSTGRES_USER,
      password: POSTGRES_PASSWORD,
    });
  }
  if (DATABASE_URL) return new pg.Pool({ connectionString: DATABASE_URL });
  throw new Error('DB 설정이 없습니다. POSTGRES_* 또는 DATABASE_URL 환경변수를 지정하세요.');
}

const CREATE_SQL = `
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
    source text NOT NULL DEFAULT 'maria-import',
    updated_at timestamptz NOT NULL DEFAULT now()
  );
  CREATE INDEX IF NOT EXISTS idx_saints_feast ON saints (feast_month, feast_day);
  CREATE INDEX IF NOT EXISTS idx_saints_name ON saints (name_ko);
`;

const UPSERT_SQL = `
  INSERT INTO saints (
    source_saint_id, name_ko, name_latin, feast_month, feast_day,
    status, kind, region_ko, region_en, year_text, detail_url, source, updated_at
  ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,'maria-import', now())
  ON CONFLICT (source_saint_id) DO UPDATE SET
    name_ko = excluded.name_ko,
    name_latin = excluded.name_latin,
    feast_month = excluded.feast_month,
    feast_day = excluded.feast_day,
    status = excluded.status,
    kind = excluded.kind,
    region_ko = excluded.region_ko,
    region_en = excluded.region_en,
    year_text = excluded.year_text,
    detail_url = excluded.detail_url,
    updated_at = now()
  WHERE saints.source <> 'manual'
  RETURNING (xmax = 0) AS inserted;
`;

async function upsertRow(pool, r) {
  const res = await pool.query(UPSERT_SQL, [
    r.id,
    r.nameKo,
    r.nameLatin,
    r.feastMonth,
    r.feastDay,
    r.status,
    r.kind,
    r.regionKo,
    r.regionEn,
    r.yearText,
    r.detailUrl,
  ]);
  if (res.rows.length === 0) return 'skipped'; // source='manual' → 보존
  return res.rows[0].inserted ? 'inserted' : 'updated';
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const args = parseArgs(process.argv);
  const psize = args.psize;

  // 총 개수/페이지 수 파악 (page 지정 시 그 한 페이지만)
  const firstPage = args.page ?? 1;
  const firstHtml = await fetchPage(firstPage, psize);
  const total = parseTotal(firstHtml);
  const totalPages = args.page ? 1 : total ? Math.ceil(total / psize) : 1;
  console.log(`총 성인: ${total ?? '알 수 없음'} · psize=${psize} · 대상 페이지=${args.page ?? `1..${totalPages}`}`);

  const counts = { inserted: 0, updated: 0, skipped: 0, parsed: 0 };
  const pool = args.dry ? null : await createPool();
  if (pool) await pool.query(CREATE_SQL);

  const pages = args.page ? [args.page] : Array.from({ length: totalPages }, (_, i) => i + 1);
  for (const page of pages) {
    const html = page === firstPage ? firstHtml : await fetchPage(page, psize);
    const rows = parseRows(html);
    counts.parsed += rows.length;
    console.log(`page ${page}: ${rows.length} rows`);
    if (args.dry) {
      for (const r of rows.slice(0, 5)) console.log('  ', JSON.stringify(r));
    } else {
      for (const r of rows) {
        try {
          counts[await upsertRow(pool, r)]++;
        } catch (e) {
          console.error(`  upsert 실패 id=${r.id}: ${e.message}`);
        }
      }
    }
    if (page !== pages[pages.length - 1]) await sleep(PAGE_DELAY_MS);
  }

  if (pool) await pool.end();
  console.log(
    `완료: 파싱 ${counts.parsed}건` +
      (args.dry
        ? ' (dry-run, DB 미기록)'
        : ` · 신규 ${counts.inserted} · 갱신 ${counts.updated} · 수동보존(skip) ${counts.skipped}`),
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
