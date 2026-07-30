// CBCK MissaLoad 응답 파서(parseEntry 등) 회귀 테스트.
// 실행: (server/ 에서) `npm test`  또는  `node --test`
//
// 스크래핑 파서라 CBCK 마크업이 바뀌면 조용히 틀릴 수 있으므로, 대표 입력에 대한
// 현재 동작을 고정해 회귀를 잡는다.
import { test } from 'node:test';
import assert from 'node:assert/strict';

import { parseEntry, cleanTitle, tagColor, stripLeadingTag } from '../src/index.js';

test('평일(녹): 색·제목·독서·링크(상대 URL 절대화)', () => {
  const day = parseEntry({
    start: '2026-07-15',
    title_html: '[녹] 연중 제15주간 수요일',
    goodnews: '탈출 3,1-6.9-12<br />마태 11,25-27',
    url: '/DailyMissa/20260715',
  });
  assert.equal(day.date, '2026-07-15');
  assert.equal(day.color, 'green');
  assert.equal(day.title, '연중 제15주간 수요일');
  assert.deepEqual(day.readings, ['탈출 3,1-6.9-12', '마태 11,25-27']);
  assert.equal(day.url, 'https://missa.cbck.or.kr/DailyMissa/20260715');
  assert.equal('alternatives' in day, false);
  assert.equal('special' in day, false);
});

test('대축일(백): "- 낮 미사" 꼬리 제거, 절대 URL 유지', () => {
  const day = parseEntry({
    start: '2026-12-25',
    title_html: '[백] 주님 성탄 대축일 - 낮 미사',
    url: 'https://missa.cbck.or.kr/DailyMissa/20261225',
  });
  assert.equal(day.color, 'white');
  assert.equal(day.title, '주님 성탄 대축일');
  assert.equal(day.url, 'https://missa.cbck.or.kr/DailyMissa/20261225');
});

test('"또는" 선택 기념일: primary + alternatives 분리', () => {
  const day = parseEntry({
    start: '2026-07-14',
    title_html: '[녹] 연중 제15주간 화요일 또는 [백] 성 카밀로 데 렐리스 사제 기념',
  });
  assert.equal(day.color, 'green');
  assert.equal(day.title, '연중 제15주간 화요일');
  assert.deepEqual(day.alternatives, [
    { name: '성 카밀로 데 렐리스 사제 기념', color: 'white' },
  ]);
});

test('special(특별 주일) 필드 반영', () => {
  const day = parseEntry({
    start: '2026-01-01',
    title_html: '[백] 천주의 성모 마리아 대축일',
    special: '세계 평화의 날',
  });
  assert.equal(day.color, 'white');
  assert.equal(day.special, '세계 평화의 날');
});

test('색 태그가 없으면 green 으로 기본 처리(현재 동작 고정)', () => {
  const day = parseEntry({ start: '2026-07-16', title_html: '연중 제15주간 목요일' });
  assert.equal(day.color, 'green');
  assert.equal(day.title, '연중 제15주간 목요일');
});

test('title_html 이 없으면 title 로 폴백', () => {
  const day = parseEntry({ start: '2026-07-17', title: '[홍] 성 보나벤투라 주교 학자 기념' });
  assert.equal(day.color, 'red');
  assert.equal(day.title, '성 보나벤투라 주교 학자 기념');
});

test('헬퍼 단위: tagColor / stripLeadingTag / cleanTitle', () => {
  assert.equal(tagColor('[자] 사순 제1주일'), 'violet');
  assert.equal(tagColor('태그 없음'), null);
  assert.equal(stripLeadingTag('[백] 주님 봉헌 축일'), '주님 봉헌 축일');
  assert.equal(cleanTitle('주님 부활 대축일 - 파스카 성야'), '주님 부활 대축일');
  assert.equal(cleanTitle('연중 제2주일'), '연중 제2주일');
});
