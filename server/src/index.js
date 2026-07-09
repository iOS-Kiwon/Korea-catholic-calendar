// 가톨릭 달력 — CBCK 전례력 캐시 게이트웨이 (Cloudflare Worker)
//
// 앱 → 이 Worker → (캐시 미스 시 1회) CBCK. 전례력 데이터는 발행 후 불변이므로
// 한 연도당 CBCK를 사실상 1회만 호출하고, 이후 모든 요청은 KV 캐시에서 응답한다.
// 미발행 연도는 available:false(짧은 TTL) → 앱은 기기 계산 엔진으로 폴백.
//
// 엔드포인트:  GET /v1/calendar/:year   →  { year, available, source?, days? }

const CBCK = 'https://missa.cbck.or.kr';

const COLOR_BY_TAG = {
  '녹': 'green', '홍': 'red', '백': 'white',
  '자': 'violet', '장': 'rose', '흑': 'black',
};

const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, OPTIONS',
  'content-type': 'application/json; charset=utf-8',
};

const stripTags = (s) => s.replace(/<[^>]*>/g, '').replace(/ /g, ' ').trim();
const tagColor = (seg) => {
  const m = seg.match(/\[(.)\]/);
  return m ? COLOR_BY_TAG[m[1]] : null;
};
const stripLeadingTag = (seg) => seg.replace(/^\s*\[.\]\s*/, '').trim();
const cleanTitle = (s) => s.replace(/\s*-\s*[^-]*(미사|성야)\s*$/, '').trim();

// CBCK MissaLoad 엔트리 → 우리 스키마(day). 앱/임포터와 동일한 형태.
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

async function fetchYearFromCbck(year) {
  const url = `${CBCK}/MissaLoad?start=${year}-01-01&end=${year}-12-31`;
  const res = await fetch(url, {
    headers: {
      'x-requested-with': 'XMLHttpRequest',
      accept: 'application/json',
      'user-agent': 'catholic-calendar-cache/1.0 (+caching gateway; minimizes upstream load)',
    },
  });
  if (!res.ok) throw new Error(`CBCK HTTP ${res.status}`);
  const arr = await res.json();
  const byDate = {};
  for (const e of arr) {
    const d = parseEntry(e);
    if (!(d.date in byDate)) byDate[d.date] = d; // 첫 항목(그날의 미사) 유지
  }
  return Object.values(byDate).sort((a, b) => a.date.localeCompare(b.date));
}

function json(body, extraHeaders) {
  return new Response(JSON.stringify(body), { headers: { ...CORS, ...extraHeaders } });
}

async function handleYear(year, env) {
  const key = `cal:${year}`;

  const cached = await env.CAL.get(key);
  if (cached) return new Response(cached, { headers: { ...CORS, 'x-cache': 'HIT' } });

  // 미발행으로 확인된 연도는 짧은 TTL 동안 CBCK 재호출을 건너뜀.
  if (await env.CAL.get(`neg:${year}`)) {
    return json({ year, available: false }, { 'x-cache': 'HIT-NEG' });
  }

  let days;
  try {
    days = await fetchYearFromCbck(year);
  } catch (_) {
    return json({ year, available: false, error: 'upstream' }, { 'x-cache': 'ERROR' });
  }

  if (days.length === 0) {
    // 아직 발행 전 → 하루 뒤 재시도.
    await env.CAL.put(`neg:${year}`, '1', { expirationTtl: 86400 });
    return json({ year, available: false }, { 'x-cache': 'MISS-EMPTY' });
  }

  const body = JSON.stringify({ year, available: true, source: 'cbck', days });
  // 발행된 데이터는 불변에 가까움 → 길게 캐시(간헐적 정정 반영 위해 30일).
  await env.CAL.put(key, body, { expirationTtl: 60 * 60 * 24 * 30 });
  return new Response(body, { headers: { ...CORS, 'x-cache': 'MISS' } });
}

export default {
  async fetch(req, env) {
    if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });
    const url = new URL(req.url);
    const m = url.pathname.match(/^\/v1\/calendar\/(\d{4})$/);
    if (m) return handleYear(Number(m[1]), env);
    if (url.pathname === '/' || url.pathname === '/health') {
      return new Response('catholic-calendar cache gateway ok', {
        headers: { 'content-type': 'text/plain; charset=utf-8' },
      });
    }
    return new Response('Not found', { status: 404 });
  },

  // 매일 실행: 인접 연도를 미리 채워 사용자 요청이 CBCK를 건드리지 않게 함.
  async scheduled(event, env) {
    const y = new Date(event.scheduledTime).getUTCFullYear();
    for (const year of [y - 1, y, y + 1, y + 2]) {
      try {
        const days = await fetchYearFromCbck(year);
        if (days.length) {
          await env.CAL.put(
            `cal:${year}`,
            JSON.stringify({ year, available: true, source: 'cbck', days }),
            { expirationTtl: 60 * 60 * 24 * 30 },
          );
        }
      } catch (_) {
        /* 다음 실행에서 재시도 */
      }
    }
  },
};
