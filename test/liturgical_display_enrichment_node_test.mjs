import assert from 'node:assert/strict';
import test from 'node:test';

import {
  enrichCalendarPayloadWithDisplayTypes,
} from '../server-app/src/liturgical-display-enrichment.js';

test('marks liturgical-only primary titles as liturgy', async () => {
  const result = await enrichCalendarPayloadWithDisplayTypes({
    available: true,
    days: [
      {
        date: '2026-11-02',
        title: '위령의 날',
        color: 'violet',
      },
    ],
  });

  assert.equal(result.changed, true);
  assert.equal(result.payload.days[0].displayType, 'liturgy');
  assert.equal(result.payload.days[0].displayMatchStatus, 'defaultLiturgy');
});

test('marks a single same-date saint match as saintFeast', async () => {
  const result = await enrichCalendarPayloadWithDisplayTypes(
    {
      available: true,
      days: [
        {
          date: '2026-07-04',
          title: '연중 제13주간 토요일',
          color: 'green',
          alternatives: [
            {
              name: '포르투갈의 성녀 엘리사벳',
              color: 'white',
            },
          ],
        },
      ],
    },
    {
      findSaintCandidates: async ({ queries, month, day }) => {
        assert.equal(month, 7);
        assert.equal(day, 4);
        assert.ok(queries.includes('엘리사벳'));
        return [{ id: 1, name: '엘리사벳' }];
      },
    },
  );

  assert.equal(result.changed, true);
  assert.equal(result.payload.days[0].displayType, 'liturgy');
  assert.equal(result.payload.days[0].alternatives[0].displayType, 'saintFeast');
  assert.equal(result.payload.days[0].alternatives[0].displayMatchStatus, 'autoMatched');
});

test('manual decisions override automatic review', async () => {
  const result = await enrichCalendarPayloadWithDisplayTypes(
    {
      available: true,
      days: [
        {
          date: '2026-08-25',
          title: '연중 제21주간 화요일',
          color: 'green',
          alternatives: [
            {
              name: '성 루도비코',
              color: 'white',
            },
          ],
        },
      ],
    },
    {
      findManualDecision: async ({ source, title }) => {
        if (source === 'alternative' && title === '성 루도비코') {
          return { displayType: 'saintFeast', note: 'confirmed rule' };
        }
        return null;
      },
    },
  );

  assert.equal(result.payload.days[0].alternatives[0].displayType, 'saintFeast');
  assert.equal(result.payload.days[0].alternatives[0].displayMatchStatus, 'manualRule');
  assert.equal(result.payload.days[0].alternatives[0].displayReason, 'confirmed rule');
});
