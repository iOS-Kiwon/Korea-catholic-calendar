// 가톨릭 달력 — CBCK 전례력 캐시 게이트웨이 (Cloudflare Worker)
//
// 앱 → 이 Worker → (캐시 미스 시 1회) CBCK. 전례력은 발행 후 불변이라, 한 달치를
// 한 번만 CBCK에서 가져와 KV에 캐시하고 이후 요청은 캐시로 응답한다.
//
// 부하 최소화 원칙:
//  - "월 단위"로만 요청(브라우저가 하던 작은 창과 유사). 한 번에 1년/여러 해를
//    통째로 긁지 않는다 → 요청 1건당 CBCK 호출은 최대 1회, 응답도 작다.
//  - 이미 캐시된 달은 CBCK를 다시 부르지 않는다.
//  - cron 프리워밍은 매시간 1개월만, 마지막 저장 월 다음부터 순차적으로 진행한다.
//  - 실제 웹사이트와 동일한 헤더/User-Agent로 호출.
//
// 엔드포인트:  GET /v1/calendar/:year/:month  →  { year, month, available, source?, days? }

const CBCK = 'https://missa.cbck.or.kr';

// 실제 매일미사 웹사이트의 XHR과 동일하게 맞춘 헤더(쿠키·GA 제외).
const BROWSER_HEADERS = {
  accept: 'application/json, text/javascript, */*; q=0.01',
  'accept-language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
  referer: 'https://missa.cbck.or.kr/',
  'user-agent':
    'Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Mobile Safari/537.36',
  'x-requested-with': 'XMLHttpRequest',
  'sec-ch-ua': '"Not;A=Brand";v="8", "Chromium";v="150", "Google Chrome";v="150"',
  'sec-ch-ua-mobile': '?1',
  'sec-ch-ua-platform': '"Android"',
  'sec-fetch-dest': 'empty',
  'sec-fetch-mode': 'cors',
  'sec-fetch-site': 'same-origin',
};

const COLOR_BY_TAG = {
  '녹': 'green', '홍': 'red', '백': 'white',
  '자': 'violet', '장': 'rose', '흑': 'black',
};

const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, OPTIONS',
  'content-type': 'application/json; charset=utf-8',
};

const pad2 = (n) => String(n).padStart(2, '0');
const monthKey = (year, month) => `cal:${year}-${pad2(month)}`;

const stripTags = (s) => s.replace(/<[^>]*>/g, '').replace(/ /g, ' ').trim();
const tagColor = (seg) => {
  const m = seg.match(/\[(.)\]/);
  return m ? COLOR_BY_TAG[m[1]] : null;
};
const stripLeadingTag = (seg) => seg.replace(/^\s*\[.\]\s*/, '').trim();
const cleanTitle = (s) => s.replace(/\s*-\s*[^-]*(미사|성야)\s*$/, '').trim();

function parseEntry(e) {
  const titleHtml = e.title_html || e.title || '';
  const segs = titleHtml.split('또는');
  const primary = stripTags(segs[0]);
  const day = {
    date: e.start,
    color: tagColor(primary) || 'green',
    title: cleanTitle(stripLeadingTag(primary)),
  };
  const alternatives = [];
  for (const seg of segs.slice(1)) {
    const c = stripTags(seg);
    if (!c) continue;
    alternatives.push({ name: stripLeadingTag(c), color: tagColor(c) || 'white' });
  }
  const readings = (e.goodnews || '').split('<br />').map(stripTags).filter(Boolean);
  const special = (e.special || '').trim();
  const url = (e.url || '').trim();
  if (special) day.special = special;
  if (readings.length) day.readings = readings;
  if (alternatives.length) day.alternatives = alternatives;
  if (url) day.url = url.startsWith('http') ? url : CBCK + url;
  return day;
}

// CBCK에서 한 달치만 조회(작은 창). 실제 사이트와 동일 헤더 + 캐시버스터.
async function fetchMonthFromCbck(year, month) {
  const last = new Date(Date.UTC(year, month, 0)).getUTCDate();
  const start = `${year}-${pad2(month)}-01`;
  const end = `${year}-${pad2(month)}-${pad2(last)}`;
  const url = `${CBCK}/MissaLoad?start=${start}&end=${end}&_=${Date.now()}`;
  const res = await fetch(url, { headers: BROWSER_HEADERS });
  if (!res.ok) throw new Error(`CBCK HTTP ${res.status}`);
  const arr = await res.json();
  const byDate = {};
  for (const e of arr) {
    const d = parseEntry(e);
    if (!(d.date in byDate)) byDate[d.date] = d; // 그날의 미사(첫 항목) 유지
  }
  return Object.values(byDate).sort((a, b) => a.date.localeCompare(b.date));
}

const json = (body, extra) =>
  new Response(JSON.stringify(body), { headers: { ...CORS, ...(extra || {}) } });

const TTL_NEG = 60 * 60 * 24; // 미발행 재시도 1일
const LAST_CACHED_MONTH_KEY = 'meta:last_cached_month';

const formatMonth = ({ year, month }) => `${year}-${pad2(month)}`;

function parseMonth(value) {
  const m = String(value || '').match(/^(\d{4})-(\d{2})$/);
  if (!m) return null;
  const year = Number(m[1]);
  const month = Number(m[2]);
  if (month < 1 || month > 12) return null;
  return { year, month };
}

function compareMonth(a, b) {
  return (a.year - b.year) || (a.month - b.month);
}

function nextMonth({ year, month }) {
  return month === 12 ? { year: year + 1, month: 1 } : { year, month: month + 1 };
}

function monthFromKstTime(time) {
  const kst = new Date(time + (9 * 60 * 60 * 1000));
  return { year: kst.getUTCFullYear(), month: kst.getUTCMonth() + 1 };
}

async function getLatestStoredMonth(env) {
  let latest = parseMonth(await env.CAL.get(LAST_CACHED_MONTH_KEY));
  let cursor;
  do {
    const page = await env.CAL.list({ prefix: 'cal:', cursor });
    for (const item of page.keys) {
      const parsed = parseMonth(item.name.slice('cal:'.length));
      if (parsed && (!latest || compareMonth(parsed, latest) > 0)) latest = parsed;
    }
    cursor = page.list_complete ? undefined : page.cursor;
  } while (cursor);
  return latest;
}

async function rememberStoredMonth(env, year, month) {
  const next = { year, month };
  const latest = parseMonth(await env.CAL.get(LAST_CACHED_MONTH_KEY));
  if (!latest || compareMonth(next, latest) > 0) {
    await env.CAL.put(LAST_CACHED_MONTH_KEY, formatMonth(next));
  }
}

async function handleMonth(year, month, env) {
  if (month < 1 || month > 12) return json({ error: 'bad month' }, { status: 400 });
  const key = monthKey(year, month);

  const cached = await env.CAL.get(key);
  if (cached) return new Response(cached, { headers: { ...CORS, 'x-cache': 'HIT' } });

  if (await env.CAL.get(`neg:${key}`)) {
    return json({ year, month, available: false }, { 'x-cache': 'HIT-NEG' });
  }

  let days;
  try {
    days = await fetchMonthFromCbck(year, month);
  } catch (_) {
    return json({ year, month, available: false, error: 'upstream' }, { 'x-cache': 'ERROR' });
  }

  if (days.length === 0) {
    await env.CAL.put(`neg:${key}`, '1', { expirationTtl: TTL_NEG }); // 아직 미발행 → 하루 뒤 재시도
    return json({ year, month, available: false }, { 'x-cache': 'MISS-EMPTY' });
  }

  const body = JSON.stringify({ year, month, available: true, source: 'cbck', days });
  await env.CAL.put(key, body);
  await rememberStoredMonth(env, year, month);
  return new Response(body, { headers: { ...CORS, 'x-cache': 'MISS' } });
}

export default {
  async fetch(req, env) {
    if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });
    const url = new URL(req.url);
    const m = url.pathname.match(/^\/v1\/calendar\/(\d{4})\/(\d{1,2})$/);
    if (m) return handleMonth(Number(m[1]), Number(m[2]), env);
    if (url.pathname === '/' || url.pathname === '/health') {
      return new Response('catholic-calendar cache gateway ok', {
        headers: { 'content-type': 'text/plain; charset=utf-8' },
      });
    }
    return new Response('Not found', { status: 404 });
  },

  // 매시간: 마지막 저장 월 다음부터 1개월만 프리워밍한다.
  async scheduled(event, env) {
    const latest = await getLatestStoredMonth(env);
    const base = latest || monthFromKstTime(event.scheduledTime);
    const target = latest ? nextMonth(base) : base;
    const { year, month } = target;
    const key = monthKey(year, month);

    if (await env.CAL.get(key)) {
      await rememberStoredMonth(env, year, month);
      return;
    }

    try {
      const days = await fetchMonthFromCbck(year, month);
      if (days.length) {
        await env.CAL.put(
          key,
          JSON.stringify({ year, month, available: true, source: 'cbck', days }),
        );
        await rememberStoredMonth(env, year, month);
      }
    } catch (_) {
      /* 다음 실행에서 재시도 */
    }
  },
};
