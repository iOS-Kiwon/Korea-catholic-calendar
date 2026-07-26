#!/usr/bin/env node

// Applies manual decisions from docs/liturgical-display-YYYY-review.md to the
// generated assets/calendar/liturgical_display_YYYY.json dataset.
//
// Usage:
//   node scripts/apply-liturgical-display-review.mjs --year 2026

import fs from 'node:fs/promises';

const args = parseArgs(process.argv.slice(2));
const year = Number(args.year || 2026);
const reviewPath =
  args.review || `docs/liturgical-display-${year}-review.md`;
const datasetPath =
  args.dataset || `assets/calendar/liturgical_display_${year}.json`;

const review = await fs.readFile(reviewPath, 'utf8');
const dataset = JSON.parse(await fs.readFile(datasetPath, 'utf8'));

const decisions = parseReviewDecisions(review);
const entriesByKey = new Map();
for (const entry of dataset.entries || []) {
  const key = decisionKey(entry.date, entry.source, entry.title);
  if (entriesByKey.has(key)) {
    throw new Error(`Duplicate dataset entry key: ${key}`);
  }
  entriesByKey.set(key, entry);
}

let applied = 0;
let saintFeast = 0;
let liturgy = 0;

for (const decision of decisions) {
  const entry = entriesByKey.get(
    decisionKey(decision.date, decision.source, decision.title),
  );
  if (!entry) {
    throw new Error(
      `Review row has no matching dataset entry: ${decision.date} ${decision.source} ${decision.title}`,
    );
  }

  entry.manualDecision = decision.value;
  entry.manualNote = decision.note || '사용자 수동 확정';
  entry.matchStatus = 'manualConfirmed';

  if (!entry.reviewReason) {
    entry.reviewReason = entry.reason || '';
  }

  if (decision.value === '축일') {
    entry.displayType = 'saintFeast';
    entry.reason = 'user confirmed as saint feast';
    saintFeast += 1;
  } else if (decision.value === '전례') {
    entry.displayType = 'liturgy';
    entry.reason = 'user confirmed as liturgy';
    liturgy += 1;
  } else if (decision.value === '보류') {
    entry.displayType = 'review';
    entry.matchStatus = 'manualReview';
    entry.reason = entry.reviewReason || 'manual review pending';
  } else {
    throw new Error(
      `Unsupported manual decision "${decision.value}" for ${decision.date} ${decision.title}`,
    );
  }

  applied += 1;
}

dataset.stats = summarize(dataset.entries || []);

await fs.writeFile(datasetPath, `${JSON.stringify(dataset, null, 2)}\n`);

console.log(
  `applied ${applied} manual decisions to ${datasetPath}: ${saintFeast} saintFeast, ${liturgy} liturgy`,
);
console.log(
  `remaining review entries: ${dataset.stats.byDisplayType.review || 0}`,
);

function parseReviewDecisions(markdown) {
  const decisions = [];
  let inManualReview = false;

  for (const line of markdown.split(/\r?\n/)) {
    if (line === '## 수동 검토 필요') {
      inManualReview = true;
      continue;
    }
    if (inManualReview && line.startsWith('## ')) {
      break;
    }
    if (!inManualReview || !line.startsWith('| 2026-')) {
      continue;
    }

    const cells = line
      .trim()
      .replace(/^\|/, '')
      .replace(/\|$/, '')
      .split('|')
      .map((cell) => unescapeCell(cell.trim()));

    const [date, source, title, , , , value, note] = cells;
    if (!value) {
      throw new Error(`Missing manual decision: ${line}`);
    }
    decisions.push({ date, source, title, value, note });
  }

  return decisions;
}

function decisionKey(date, source, title) {
  return [date, source, normalizeTitle(title)].join('\u0000');
}

function normalizeTitle(value) {
  return String(value || '')
    .replace(/\u00a0/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function unescapeCell(value) {
  return String(value || '').replace(/\\\|/g, '|');
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
