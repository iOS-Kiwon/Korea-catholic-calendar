const rankSuffixPattern =
  /\s*(대축일|축일|의무 기념일|선택 기념일|기념일)\s*$/;
const saintPrefixPattern =
  /^(성녀|성인|성|복녀|복자|복되신)\s+/;
const saintDescriptorWords = new Set([
  '교황',
  '주교',
  '사제',
  '부제',
  '수도자',
  '수도원장',
  '아빠스',
  '동정',
  '순교자',
  '학자',
  '복음사가',
  '사도',
  '은수자',
  '왕',
  '여왕',
]);

export function extractSingleSaintQuery(title) {
  let text = String(title || '').trim();
  if (!text) return '';
  if (!text.includes('성') && !text.includes('복자') && !text.includes('복녀')) {
    return '';
  }
  if (/[,&]/.test(text) || /(와|과|및)\s+성/.test(text)) return '';
  if (text.includes('모든 성인') || text.includes('위령의 날')) return '';

  text = text.replace(/\([^)]*\)/g, ' ');
  text = text.replace(rankSuffixPattern, '').trim();
  text = text.replace(saintPrefixPattern, '').trim();
  if (!text) return '';

  const words = text.split(/\s+/).filter(Boolean);
  while (
    words.length > 1 &&
    saintDescriptorWords.has(words[words.length - 1])
  ) {
    words.pop();
  }

  const query = words.join(' ').trim();
  if (!query || saintDescriptorWords.has(query)) return '';
  return query;
}

export async function enrichCalendarPayloadWithSaintUrls(payload, findSaintUrl) {
  if (!payload || !Array.isArray(payload.days)) return { payload, changed: false };

  let changed = false;
  const days = [];
  for (const day of payload.days) {
    if (!day || typeof day !== 'object') {
      days.push(day);
      continue;
    }
    const date = parseDayDate(day.date);
    const query = extractSingleSaintQuery(day.title);
    if (!date || !query) {
      days.push(day);
      continue;
    }

    const saintInfoUrl = await findSaintUrl({
      query,
      month: date.month,
      day: date.day,
      title: day.title,
      date: day.date,
    });
    if (saintInfoUrl && saintInfoUrl !== day.saintInfoUrl) {
      days.push({ ...day, saintInfoUrl });
      changed = true;
    } else {
      days.push(day);
    }
  }

  return changed ? { payload: { ...payload, days }, changed } : { payload, changed };
}

function parseDayDate(value) {
  const match = String(value || '').match(/^\d{4}-(\d{2})-(\d{2})$/);
  if (!match) return null;
  const month = Number(match[1]);
  const day = Number(match[2]);
  if (!Number.isInteger(month) || !Number.isInteger(day)) return null;
  return { month, day };
}
