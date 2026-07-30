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

export function liturgicalDisplayTitleKey(value) {
  return normalizeText(value).toLowerCase();
}

export async function enrichCalendarPayloadWithDisplayTypes(
  payload,
  { findManualDecision, findSaintCandidates } = {},
) {
  if (!payload || !Array.isArray(payload.days)) {
    return { payload, changed: false };
  }

  let changed = false;
  const days = [];
  for (const day of payload.days) {
    if (!day || typeof day !== 'object') {
      days.push(day);
      continue;
    }

    const date = String(day.date || '');
    const enrichedDay = { ...day };
    const primary = await classifyDisplayEntry({
      date,
      source: 'primary',
      sourceIndex: 0,
      title: day.title,
      existingDisplayType: day.displayType,
      findManualDecision,
      findSaintCandidates,
    });

    if (primary && applyDisplayResult(enrichedDay, primary)) {
      changed = true;
    }

    const alternatives = [];
    for (const [index, alternative] of (day.alternatives || []).entries()) {
      if (!alternative || typeof alternative !== 'object') {
        alternatives.push(alternative);
        continue;
      }
      const enrichedAlternative = { ...alternative };
      const result = await classifyDisplayEntry({
        date,
        source: 'alternative',
        sourceIndex: index,
        title: alternative.name,
        existingDisplayType: alternative.displayType,
        findManualDecision,
        findSaintCandidates,
      });
      if (result && applyDisplayResult(enrichedAlternative, result)) {
        changed = true;
      }
      alternatives.push(enrichedAlternative);
    }
    if (alternatives.length > 0) enrichedDay.alternatives = alternatives;
    days.push(enrichedDay);
  }

  return changed ? { payload: { ...payload, days }, changed } : { payload, changed };
}

export async function classifyDisplayEntry({
  date,
  source,
  sourceIndex,
  title,
  existingDisplayType,
  findManualDecision,
  findSaintCandidates,
}) {
  const normalizedTitle = normalizeText(title);
  if (!normalizedTitle) return null;

  const manualDecision = await findManualDecision?.({
    date,
    source,
    sourceIndex,
    title: normalizedTitle,
    titleKey: liturgicalDisplayTitleKey(normalizedTitle),
  });
  if (manualDecision?.displayType) {
    return {
      displayType: manualDecision.displayType,
      displayMatchStatus: manualDecision.matchStatus || 'manualRule',
      displayReason: manualDecision.note || 'manual display decision',
    };
  }

  if (existingDisplayType === 'liturgy' || existingDisplayType === 'saintFeast') {
    return null;
  }

  if (isLiturgicalOnlyTitle(normalizedTitle)) {
    return {
      displayType: 'liturgy',
      displayMatchStatus: 'defaultLiturgy',
      displayReason: 'liturgical-only title pattern',
    };
  }

  if (source === 'primary' && !isPrimarySaintCandidate(normalizedTitle)) {
    return {
      displayType: 'liturgy',
      displayMatchStatus: 'defaultLiturgy',
      displayReason: 'primary title without saint-feast marker',
    };
  }

  if (isGroupedSaintTitle(normalizedTitle)) {
    return {
      displayType: 'review',
      displayMatchStatus: 'manualReview',
      displayReason: 'grouped saint title',
    };
  }

  const dateParts = parseDayDate(date);
  const queries = queryVariants(normalizedTitle);
  if (!dateParts || queries.length === 0) {
    return {
      displayType: 'review',
      displayMatchStatus: 'manualReview',
      displayReason: dateParts ? 'no saint query extracted' : 'invalid date',
    };
  }

  const candidates =
    (await findSaintCandidates?.({
      queries,
      month: dateParts.month,
      day: dateParts.day,
      title: normalizedTitle,
      date,
    })) || [];

  if (candidates.length === 1) {
    return {
      displayType: 'saintFeast',
      displayMatchStatus: 'autoMatched',
      displayReason: 'same-date single saint match',
    };
  }

  return {
    displayType: 'review',
    displayMatchStatus: 'manualReview',
    displayReason:
      candidates.length === 0
        ? 'no same-date saint match'
        : 'multiple same-date saint matches',
  };
}

function applyDisplayResult(target, result) {
  const before = [
    target.displayType,
    target.displayMatchStatus,
    target.displayReason,
  ].join('\u0000');
  target.displayType = result.displayType;
  target.displayMatchStatus = result.displayMatchStatus;
  target.displayReason = result.displayReason;
  const after = [
    target.displayType,
    target.displayMatchStatus,
    target.displayReason,
  ].join('\u0000');
  return before !== after;
}

function parseDayDate(value) {
  const match = String(value || '').match(/^\d{4}-(\d{2})-(\d{2})$/);
  if (!match) return null;
  const month = Number(match[1]);
  const day = Number(match[2]);
  if (!Number.isInteger(month) || !Number.isInteger(day)) return null;
  return { month, day };
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

  return [...variants].filter(Boolean);
}

function addQueryVariants(variants, raw) {
  let text = normalizeText(raw).replace(rankSuffixPattern, '').trim();
  if (!text) return;
  while (trailingDescriptorPattern.test(text)) {
    text = text.replace(trailingDescriptorPattern, '').trim();
  }
  if (text) variants.add(text);
  const first = text.split(/\s+/)[0];
  if (first && first.length >= 2) variants.add(first);
}

function normalizeText(value) {
  return String(value || '')
    .replace(/\u00a0/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}
