import fs from 'node:fs';

const assetRootCandidates = [
  new URL('../assets/calendar/', import.meta.url),
  new URL('../../assets/calendar/', import.meta.url),
];

const fixedCelebrationFiles = ['general.json', 'korea.json'];
const shortTitleFile = process.env.LITURGICAL_SHORT_TITLES_FILE || '';

let cachedConfig = null;

export function enrichCalendarPayloadWithShortTitles(payload) {
  const config = loadConfig();
  if (!payload || !Array.isArray(payload.days)) {
    return { payload, changed: false };
  }

  let changed = false;
  const days = payload.days.map((day) => {
    if (!day || typeof day.date !== 'string') return day;
    const id = celebrationIdOn(day.date, config);
    const shortTitle = id ? config.shortTitles[id] : '';
    if (!id || !shortTitle) return day;
    if (day.celebrationId === id && day.shortTitle === shortTitle) return day;
    changed = true;
    return { ...day, celebrationId: id, shortTitle };
  });

  return changed ? { payload: { ...payload, days }, changed } : { payload, changed };
}

function loadConfig() {
  if (cachedConfig) return cachedConfig;
  const shortTitles = loadShortTitles();
  cachedConfig = {
    shortTitles,
    fixedCelebrations: loadFixedCelebrations(shortTitles),
    adaptation: loadAdaptation(),
    fixedByYear: new Map(),
  };
  return cachedConfig;
}

function loadShortTitles() {
  const file = shortTitleFile || assetUrl('liturgical_short_titles.json');
  const doc = JSON.parse(fs.readFileSync(file, 'utf8'));
  return Object.fromEntries(
    Object.entries(doc.titles || {})
      .map(([id, title]) => [String(id), String(title).trim()])
      .filter(([, title]) => title),
  );
}

function loadFixedCelebrations(shortTitles) {
  const celebrations = [];
  for (const fileName of fixedCelebrationFiles) {
    const doc = JSON.parse(fs.readFileSync(assetUrl(fileName), 'utf8'));
    for (const celebration of doc.celebrations || []) {
      if (!shortTitles[celebration.id]) continue;
      if (!celebration.month || !celebration.day) continue;
      celebrations.push({
        id: celebration.id,
        month: Number(celebration.month),
        day: Number(celebration.day),
        rank: celebration.rank || '',
        precedence: celebration.precedence || precedenceForRank(celebration),
      });
    }
  }
  return celebrations;
}

function loadAdaptation() {
  try {
    const doc = JSON.parse(fs.readFileSync(assetUrl('adaptation.json'), 'utf8'));
    return {
      epiphanyOnSunday: doc.epiphanyOnSunday !== false,
      ascensionOnSunday: doc.ascensionOnSunday !== false,
      corpusChristiOnSunday: doc.corpusChristiOnSunday !== false,
    };
  } catch {
    return {
      epiphanyOnSunday: true,
      ascensionOnSunday: true,
      corpusChristiOnSunday: true,
    };
  }
}

function celebrationIdOn(dateKey, config) {
  const date = parseDateKey(dateKey);
  if (!date) return '';
  const movable = movableCelebrationIdOn(date, config.adaptation);
  if (movable) return movable;
  return fixedCelebrationsForYear(date.year, config).get(dateKey) || '';
}

function fixedCelebrationsForYear(year, config) {
  if (config.fixedByYear.has(year)) return config.fixedByYear.get(year);

  const byDate = new Map();
  for (const celebration of config.fixedCelebrations) {
    const natural = { year, month: celebration.month, day: celebration.day };
    const observed = placeFixedCelebration(
      celebration,
      natural,
      config.adaptation,
    );
    byDate.set(dateKey(observed), celebration.id);
  }

  config.fixedByYear.set(year, byDate);
  return byDate;
}

function placeFixedCelebration(celebration, natural, adaptation) {
  if (!isSolemnity(celebration)) return natural;

  const code = precedenceIndex(celebration.precedence);
  const easter = gregorianEaster(natural.year);
  const palm = addDays(easter, -7);
  const octaveEnd = addDays(easter, 7);

  if (compareDate(natural, palm) >= 0 && compareDate(natural, octaveEnd) <= 0) {
    return nextFreeForSolemnity(addDays(easter, 8), code, adaptation);
  }

  if (temporalePrecedenceIndex(natural, adaptation) < code) {
    return nextFreeForSolemnity(addDays(natural, 1), code, adaptation);
  }

  return natural;
}

function nextFreeForSolemnity(start, code, adaptation) {
  let date = start;
  for (let index = 0; index < 21; index += 1) {
    if (temporalePrecedenceIndex(date, adaptation) >= code) return date;
    date = addDays(date, 1);
  }
  return start;
}

function movableCelebrationIdOn(date, adaptation) {
  const easter = gregorianEaster(date.year);
  const epiphany = adaptation.epiphanyOnSunday
    ? sundayBetween(date.year, 1, 2, 8)
    : { year: date.year, month: 1, day: 6 };
  const ascension = addDays(easter, adaptation.ascensionOnSunday ? 42 : 39);
  const corpusChristi = addDays(easter, adaptation.corpusChristiOnSunday ? 63 : 60);
  const christmas = { year: date.year, month: 12, day: 25 };
  const christmasWeekday = weekday(christmas);
  const holyFamily = christmasWeekday === 0
    ? { year: date.year, month: 12, day: 30 }
    : addDays(christmas, 7 - christmasWeekday);

  const checks = [
    ['epiphany', epiphany],
    ['baptism_of_the_lord', baptismOfTheLord(date.year, epiphany)],
    ['holy_family', holyFamily],
    ['ash_wednesday', addDays(easter, -46)],
    ['palm_sunday', addDays(easter, -7)],
    ['holy_thursday', addDays(easter, -3)],
    ['good_friday', addDays(easter, -2)],
    ['holy_saturday', addDays(easter, -1)],
    ['easter', easter],
    ['ascension', ascension],
    ['pentecost', addDays(easter, 49)],
    ['trinity', addDays(easter, 56)],
    ['corpus_christi', corpusChristi],
    ['sacred_heart', addDays(easter, 68)],
    ['christ_the_king', addDays(adventFirstSunday(date.year), -7)],
  ];

  for (const [id, target] of checks) {
    if (sameDay(date, target)) return id;
  }
  return '';
}

function temporalePrecedenceIndex(date, adaptation) {
  const movableId = movableCelebrationIdOn(date, adaptation);
  if (
    movableId === 'holy_thursday' ||
    movableId === 'good_friday' ||
    movableId === 'holy_saturday'
  ) {
    return precedenceIndex('triduum');
  }
  if (
    movableId === 'epiphany' ||
    movableId === 'ash_wednesday' ||
    movableId === 'palm_sunday' ||
    movableId === 'easter' ||
    movableId === 'ascension' ||
    movableId === 'pentecost'
  ) {
    return precedenceIndex('privilegedSolemnity');
  }
  if (
    movableId === 'trinity' ||
    movableId === 'corpus_christi' ||
    movableId === 'sacred_heart' ||
    movableId === 'christ_the_king'
  ) {
    return precedenceIndex('generalSolemnity');
  }
  if (movableId) return precedenceIndex('feastOfTheLord');

  const season = seasonInfo(date, adaptation);
  if (weekday(date) === 0) {
    return season === 'advent' || season === 'lent' || season === 'easter'
      ? precedenceIndex('privilegedSolemnity')
      : precedenceIndex('sunday');
  }
  if (
    (season === 'advent' && date.month === 12 && date.day >= 17) ||
    season === 'lent' ||
    (season === 'easter' &&
      compareDate(date, addDays(gregorianEaster(date.year), 7)) <= 0)
  ) {
    return precedenceIndex('privilegedWeekday');
  }
  return precedenceIndex('weekday');
}

function baptismOfTheLord(year, epiphany) {
  const jan7 = { year, month: 1, day: 7 };
  const jan8 = { year, month: 1, day: 8 };
  if (compareDate(epiphany, jan7) >= 0 && compareDate(epiphany, jan8) <= 0) {
    return addDays(epiphany, 1);
  }
  return nextSundayAfter(epiphany);
}

function adventFirstSunday(year) {
  const dec24 = { year, month: 12, day: 24 };
  const fourthAdventSunday = addDays(dec24, -weekday(dec24));
  return addDays(fourthAdventSunday, -21);
}

function seasonInfo(date, adaptation) {
  const easter = gregorianEaster(date.year);
  const advent = adventFirstSunday(date.year);
  const epiphany = adaptation.epiphanyOnSunday
    ? sundayBetween(date.year, 1, 2, 8)
    : { year: date.year, month: 1, day: 6 };
  const baptism = baptismOfTheLord(date.year, epiphany);

  if (compareDate(date, advent) >= 0) return 'advent';
  if (date.month === 12 && date.day >= 25) return 'christmas';
  if (date.month === 1 && compareDate(date, baptism) <= 0) {
    return 'christmas';
  }
  if (
    compareDate(date, addDays(easter, -46)) >= 0 &&
    compareDate(date, addDays(easter, -4)) <= 0
  ) {
    return 'lent';
  }
  if (
    compareDate(date, addDays(easter, -3)) >= 0 &&
    compareDate(date, addDays(easter, -1)) <= 0
  ) {
    return 'triduum';
  }
  if (compareDate(date, easter) >= 0 && compareDate(date, addDays(easter, 49)) <= 0) {
    return 'easter';
  }
  return 'ordinaryTime';
}

function precedenceForRank(celebration) {
  if (celebration.rank === 'solemnity') {
    return celebration.properToKorea ? 'properSolemnity' : 'generalSolemnity';
  }
  if (celebration.rank === 'feastOfTheLord') return 'feastOfTheLord';
  if (celebration.rank === 'feast') {
    return celebration.properToKorea ? 'properFeast' : 'generalFeast';
  }
  if (celebration.rank === 'obligatoryMemorial') {
    return celebration.properToKorea
      ? 'properObligatoryMemorial'
      : 'generalObligatoryMemorial';
  }
  if (celebration.rank === 'optionalMemorial') return 'optionalMemorial';
  if (celebration.rank === 'privilegedFeria') return 'privilegedWeekday';
  return 'weekday';
}

function isSolemnity(celebration) {
  return (
    celebration.precedence === 'generalSolemnity' ||
    celebration.precedence === 'properSolemnity'
  );
}

function precedenceIndex(precedence) {
  return [
    'triduum',
    'privilegedSolemnity',
    'generalSolemnity',
    'properSolemnity',
    'feastOfTheLord',
    'sunday',
    'generalFeast',
    'properFeast',
    'privilegedWeekday',
    'generalObligatoryMemorial',
    'properObligatoryMemorial',
    'optionalMemorial',
    'weekday',
  ].indexOf(precedence);
}

function sundayBetween(year, month, startDay, endDay) {
  for (let day = startDay; day <= endDay; day += 1) {
    const date = { year, month, day };
    if (weekday(date) === 0) return date;
  }
  return { year, month, day: startDay };
}

function nextSundayAfter(date) {
  const days = 7 - weekday(date);
  return addDays(date, days === 0 ? 7 : days);
}

function gregorianEaster(year) {
  const a = year % 19;
  const b = Math.floor(year / 100);
  const c = year % 100;
  const d = Math.floor(b / 4);
  const e = b % 4;
  const f = Math.floor((b + 8) / 25);
  const g = Math.floor((b - f + 1) / 3);
  const h = (19 * a + b - d - g + 15) % 30;
  const i = Math.floor(c / 4);
  const k = c % 4;
  const l = (32 + 2 * e + 2 * i - h - k) % 7;
  const m = Math.floor((a + 11 * h + 22 * l) / 451);
  const month = Math.floor((h + l - 7 * m + 114) / 31);
  const day = ((h + l - 7 * m + 114) % 31) + 1;
  return { year, month, day };
}

function parseDateKey(value) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return null;
  return {
    year: Number(match[1]),
    month: Number(match[2]),
    day: Number(match[3]),
  };
}

function addDays(date, days) {
  const utc = Date.UTC(date.year, date.month - 1, date.day + days);
  const result = new Date(utc);
  return {
    year: result.getUTCFullYear(),
    month: result.getUTCMonth() + 1,
    day: result.getUTCDate(),
  };
}

function weekday(date) {
  return new Date(Date.UTC(date.year, date.month - 1, date.day)).getUTCDay();
}

function compareDate(left, right) {
  return dateSerial(left) - dateSerial(right);
}

function dateSerial(date) {
  return Date.UTC(date.year, date.month - 1, date.day);
}

function sameDay(left, right) {
  return left.year === right.year && left.month === right.month && left.day === right.day;
}

function dateKey(date) {
  return `${date.year}-${String(date.month).padStart(2, '0')}-${String(date.day).padStart(2, '0')}`;
}

function monthDayKey(month, day) {
  return `${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

function assetUrl(fileName) {
  for (const root of assetRootCandidates) {
    const url = new URL(fileName, root);
    if (fs.existsSync(url)) return url;
  }
  return new URL(fileName, assetRootCandidates[0]);
}
