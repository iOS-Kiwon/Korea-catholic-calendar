#!/usr/bin/env node

// Builds a reviewable liturgical display dataset for one calendar year.
//
// The script intentionally keeps matching conservative:
// - only a same-date, single saint API result is auto-confirmed;
// - grouped names and liturgical-only titles stay in manual review/liturgy;
// - the app should eventually consume the generated displayType instead of
//   inferring "전례/축일" from title strings at render time.
//
// Usage:
//   node scripts/build-liturgical-display-dataset.mjs --year 2026

import fs from 'node:fs/promises';
import path from 'node:path';

const args = parseArgs(process.argv.slice(2));
const year = Number(args.year || 2026);
const apiBase = String(args.apiBase || 'http://127.0.0.1:18080/kcc/v1').replace(
  /\/+$/,
  '',
);
const calendarPath = args.calendar || 'assets/calendar/cbck_days.json';
const outputPath =
  args.output || `assets/calendar/liturgical_display_${year}.json`;
const reviewPath =
  args.review || `docs/liturgical-display-${year}-review.md`;

const rankSuffixPattern =
  /\s*(대축일|축일|의무 기념일|선택 기념일|기념일)\s*$/;
const trailingDescriptorPattern =
  /\s+(교황|주교|사제|부제|수도자|수도원장|아빠스|동정|순교자|학자|복음사가|사도|은수자|왕|여왕|첫)$/;
const saintMarkerPattern = /(성녀|성인|성|복녀|복자|복되신)\s+/g;
const groupPattern = /[,，]|(?:와|과|및).*?(?:성|성녀|복자|복녀|복되신)/;

const liturgicalOnlyTitlePatterns = [
  /대축일/,
  /^주님/,
  /^주님의/,
  /주님\s/,
  /성\s*십자가/,
  /대성전\s*봉헌/,
  /성가정/,
  /위령의 날/,
  /모든 성인/,
  /수호자/,
  /기도의 날/,
  /민족/,
  /설$/,
  /한가위$/,
  /재의/,
  /성주간/,
  /성금요일/,
  /성토요일/,
];

const calendar = JSON.parse(await fs.readFile(calendarPath, 'utf8'));
const days = (calendar.days || []).filter((day) =>
  String(day.date || '').startsWith(`${year}-`),
);

const entries = [];
for (const day of days) {
  entries.push(await buildEntry(day, 'primary', 0, day.title, day.color));
  for (const [index, alternative] of (day.alternatives || []).entries()) {
    entries.push(
      await buildEntry(
        day,
        'alternative',
        index,
        alternative.name,
        alternative.color,
      ),
    );
  }
}

const stats = summarize(entries);
const dataset = {
  year,
  source: 'cbck_days + local saints API',
  apiBase,
  generatedAt: new Date().toISOString(),
  stats,
  entries,
};

await fs.mkdir(path.dirname(outputPath), { recursive: true });
await fs.writeFile(outputPath, `${JSON.stringify(dataset, null, 2)}\n`);
await fs.mkdir(path.dirname(reviewPath), { recursive: true });
await fs.writeFile(reviewPath, buildReviewMarkdown(dataset));

console.log(
  `wrote ${outputPath}: ${entries.length} entries, ` +
    `${stats.byDisplayType.saintFeast || 0} auto saintFeast, ` +
    `${stats.byMatchStatus.manualReview || 0} manualReview`,
);
console.log(`wrote ${reviewPath}`);

async function buildEntry(day, source, sourceIndex, title, color) {
  const { month, dayOfMonth } = parseDate(day.date);
  const base = {
    date: day.date,
    source,
    sourceIndex,
    title,
    color,
    dayTitle: day.title,
    dayUrl: day.url || '',
  };

  if (!title || isLiturgicalOnlyTitle(title)) {
    return {
      ...base,
      displayType: 'liturgy',
      matchStatus: 'defaultLiturgy',
      reason: 'liturgical-only title pattern',
      queries: [],
      candidates: [],
    };
  }

  if (source === 'primary' && !isPrimarySaintCandidate(title)) {
    return {
      ...base,
      displayType: 'liturgy',
      matchStatus: 'defaultLiturgy',
      reason: 'primary title without saint-feast marker',
      queries: [],
      candidates: [],
    };
  }

  if (isGroupedSaintTitle(title)) {
    return {
      ...base,
      displayType: 'review',
      matchStatus: 'manualReview',
      reason: 'grouped saint title',
      queries: queryVariants(title),
      candidates: [],
    };
  }

  const queries = queryVariants(title);
  if (queries.length === 0) {
    return {
      ...base,
      displayType: 'review',
      matchStatus: 'manualReview',
      reason: 'no saint query extracted',
      queries,
      candidates: [],
    };
  }

  const candidates = await findCandidates({
    title,
    queries,
    month,
    day: dayOfMonth,
  });
  if (candidates.length === 1) {
    return {
      ...base,
      displayType: 'saintFeast',
      matchStatus: 'autoMatched',
      reason: 'same-date single saint match',
      queries,
      saint: candidates[0],
      candidates,
    };
  }

  return {
    ...base,
    displayType: 'review',
    matchStatus: 'manualReview',
    reason: candidates.length === 0 ? 'no same-date saint match' : 'multiple same-date saint matches',
    queries,
    candidates,
  };
}

function isPrimarySaintCandidate(title) {
  return /축일|기념일/.test(title) || hasSaintMarker(title);
}

function isLiturgicalOnlyTitle(title) {
  return liturgicalOnlyTitlePatterns.some((pattern) => pattern.test(title));
}

function isGroupedSaintTitle(title) {
  return groupPattern.test(title);
}

function hasSaintMarker(title) {
  return /(성녀|성인|성|복녀|복자|복되신)\s+/.test(title);
}

function queryVariants(title) {
  let text = normalizeText(title)
    .replace(/\([^)]*\)/g, ' ')
    .replace(rankSuffixPattern, '')
    .trim();
  if (!text) return [];

  const variants = new Set();
  const markerMatches = [...text.matchAll(saintMarkerPattern)];
  if (markerMatches.length > 0) {
    const last = markerMatches[markerMatches.length - 1];
    const afterMarker = text.slice(last.index + last[0].length).trim();
    addQueryVariants(variants, afterMarker);
  }

  addQueryVariants(
    variants,
    text.replace(/^(?:.+의\s+)?(성녀|성인|성|복녀|복자|복되신)\s+/, ''),
  );
  addQueryVariants(variants, text);

  return [...variants].filter((query) => query.length >= 2).slice(0, 6);
}

function addQueryVariants(variants, value) {
  let text = normalizeText(value).replace(rankSuffixPattern, '').trim();
  while (trailingDescriptorPattern.test(text)) {
    text = text.replace(trailingDescriptorPattern, '').trim();
  }
  text = text
    .replace(/^(성녀|성인|성|복녀|복자|복되신)\s+/, '')
    .replace(/^동정\s+마리아$/, '마리아')
    .trim();
  if (!text) return;

  variants.add(text);
  const words = text.split(/\s+/).filter(Boolean);
  if (words.length > 1) {
    variants.add(words.slice(-1).join(' '));
    variants.add(words.slice(-2).join(' '));
    variants.add(words.slice(-3).join(' '));
  }
}

async function findCandidates({ title, queries, month, day }) {
  const byId = new Map();
  for (const query of queries) {
    const url = new URL(`${apiBase}/saints`);
    url.searchParams.set('q', query);
    url.searchParams.set('month', String(month));
    url.searchParams.set('day', String(day));
    url.searchParams.set('limit', '10');
    const response = await fetch(url);
    if (!response.ok) continue;
    const body = await response.json();
    for (const item of body.items || []) {
      byId.set(item.id, {
        id: item.id,
        nameKo: item.nameKo,
        nameLatin: item.nameLatin || '',
        feastMonth: item.feastMonth,
        feastDay: item.feastDay,
        status: item.status || '',
        kind: item.kind || '',
        url: item.url || '',
      });
    }
  }
  return [...byId.values()].filter((candidate) =>
    candidateNameFitsTitle(title, candidate),
  ).sort((left, right) =>
    String(left.nameKo).localeCompare(String(right.nameKo), 'ko'),
  );
}

function candidateNameFitsTitle(title, candidate) {
  const titleKey = compactForMatch(title);
  const nameKey = compactForMatch(candidate.nameKo);
  if (!titleKey || !nameKey) return false;
  return titleKey.includes(nameKey);
}

function compactForMatch(value) {
  return normalizeText(value)
    .replace(/\([^)]*\)/g, ' ')
    .replace(rankSuffixPattern, '')
    .replace(/(성녀|성인|성|복녀|복자|복되신)\s+/g, '')
    .replace(
      /\s+(교황|주교|사제|부제|수도자|수도원장|아빠스|동정|순교자|학자|복음사가|사도|은수자|왕|여왕|첫)(?=\s|$)/g,
      ' ',
    )
    .replace(/[^가-힣A-Za-z0-9]/g, '')
    .trim();
}

function parseDate(date) {
  const [, month, day] = String(date).match(/^\d{4}-(\d{2})-(\d{2})$/) || [];
  return { month: Number(month), dayOfMonth: Number(day) };
}

function normalizeText(value) {
  return String(value || '')
    .replace(/\u00a0/g, ' ')
    .replace(/[·ㆍ]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function summarize(items) {
  return {
    totalEntries: items.length,
    bySource: countBy(items, 'source'),
    byDisplayType: countBy(items, 'displayType'),
    byMatchStatus: countBy(items, 'matchStatus'),
  };
}

function countBy(items, key) {
  return items.reduce((acc, item) => {
    acc[item[key]] = (acc[item[key]] || 0) + 1;
    return acc;
  }, {});
}

function buildReviewMarkdown(dataset) {
  const review = dataset.entries.filter((entry) => entry.matchStatus === 'manualReview');
  const auto = dataset.entries.filter((entry) => entry.matchStatus === 'autoMatched');
  const lines = [
    `# ${dataset.year} 전례/축일 표시 데이터 검토`,
    '',
    `생성 시각: ${dataset.generatedAt}`,
    '',
    '## 요약',
    '',
    `- 전체 항목: ${dataset.stats.totalEntries}`,
    `- 자동 축일 확정: ${auto.length}`,
    `- 수동 검토 필요: ${review.length}`,
    `- 기본 전례: ${dataset.stats.byDisplayType.liturgy || 0}`,
    '',
    '## 수동 검토 필요',
    '',
    '| 날짜 | 원천 | 항목 | 사유 | 검색어 | 후보 | 판단 | 메모 |',
    '| --- | --- | --- | --- | --- | --- | --- | --- |',
  ];

  for (const entry of review) {
    lines.push(
      [
        entry.date,
        entry.source,
        escapeCell(entry.title),
        escapeCell(entry.reason),
        escapeCell(entry.queries.join(', ')),
        escapeCell(
          entry.candidates
            .map((candidate) => `${candidate.nameKo}(${candidate.id})`)
            .join(', '),
        ),
        '',
        '',
      ].join(' | ').replace(/^/, '| ').replace(/$/, ' |'),
    );
  }

  lines.push('', '## 자동 축일 확정', '');
  lines.push('| 날짜 | 원천 | 항목 | 성인 | URL |');
  lines.push('| --- | --- | --- | --- | --- |');
  for (const entry of auto) {
    lines.push(
      [
        entry.date,
        entry.source,
        escapeCell(entry.title),
        escapeCell(`${entry.saint.nameKo}(${entry.saint.id})`),
        escapeCell(entry.saint.url),
      ].join(' | ').replace(/^/, '| ').replace(/$/, ' |'),
    );
  }

  return `${lines.join('\n')}\n`;
}

function escapeCell(value) {
  return String(value || '').replace(/\|/g, '\\|').replace(/\n/g, ' ');
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
