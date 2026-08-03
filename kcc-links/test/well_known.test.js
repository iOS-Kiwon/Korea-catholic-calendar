import { test } from 'node:test';
import assert from 'node:assert/strict';
import worker from '../src/index.js';

const call = (path) => worker.fetch(new Request(`https://kcc.sidore.org${path}`));

test('AASA: JSON + application/json + /e/* 경로', async () => {
  const res = await call('/.well-known/apple-app-site-association');
  assert.equal(res.status, 200);
  assert.match(res.headers.get('content-type') || '', /application\/json/);
  const body = await res.json();
  const detail = body.applinks.details[0];
  assert.match(detail.appID, /\.com\.sidore\.catholiccalendar$/);
  assert.deepEqual(detail.paths, ['/e/*']);
});

test('assetlinks: 패키지명 + SHA256 지문', async () => {
  const res = await call('/.well-known/assetlinks.json');
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body[0].target.package_name, 'com.sidore.catholiccalendar');
  assert.ok(Array.isArray(body[0].target.sha256_cert_fingerprints));
  assert.ok(body[0].target.sha256_cert_fingerprints.length >= 1);
});

test('/e/<payload> 랜딩은 HTML + 앱 열기/설치 안내', async () => {
  const res = await call('/e/abc123');
  assert.equal(res.status, 200);
  assert.match(res.headers.get('content-type') || '', /text\/html/);
  const html = await res.text();
  assert.match(html, /가톨릭 달력/);
});

test('알 수 없는 경로는 404', async () => {
  const res = await call('/nope');
  assert.equal(res.status, 404);
});
