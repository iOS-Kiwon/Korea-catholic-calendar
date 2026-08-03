// kcc.sidore.org - 유니버설/앱링크 연동파일 + 공유 링크 랜딩.
// 앱 설치 시 OS가 /e/* 링크를 앱으로 가로채므로, 이 랜딩은 미설치/브라우저 폴백용.

// 선행조건: 아래 값을 실제 값으로 교체.
const APPLE_TEAM_ID = '<TEAMID>'; // 예: ABCDE12345
const IOS_BUNDLE_ID = 'com.sidore.catholiccalendar';
const ANDROID_PACKAGE = 'com.sidore.catholiccalendar';
const ANDROID_SHA256 = [
  '<SHA256_DEBUG>',   // 디버그 서명 SHA256(콜론 구분 대문자)
  '<SHA256_RELEASE>', // 릴리스 서명 SHA256
];

const json = (obj) =>
  new Response(JSON.stringify(obj), {
    headers: { 'content-type': 'application/json; charset=utf-8' },
  });

const aasa = () =>
  json({
    applinks: {
      apps: [],
      details: [{ appID: `${APPLE_TEAM_ID}.${IOS_BUNDLE_ID}`, paths: ['/e/*'] }],
    },
  });

const assetlinks = () =>
  json([
    {
      relation: ['delegate_permission/common.handle_all_urls'],
      target: {
        namespace: 'android_app',
        package_name: ANDROID_PACKAGE,
        sha256_cert_fingerprints: ANDROID_SHA256,
      },
    },
  ]);

function landing() {
  // 미설치/브라우저 폴백: 앱에서 열기 시도 + 스토어 안내(스토어 미출시 전엔 안내 문구).
  const html = `<!doctype html><html lang="ko"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>가톨릭 달력 - 일정 공유</title></head>
<body style="font-family:system-ui;max-width:480px;margin:40px auto;padding:0 16px">
<h1>가톨릭 달력</h1>
<p>공유된 일정을 열려면 가톨릭 달력 앱이 필요합니다.</p>
<p><a href="#" onclick="location.href=location.href.replace('https://kcc.sidore.org/e/','catholiccalendar://e/');return false;">앱에서 열기</a></p>
<p>앱이 없으면 설치 후 다시 링크를 눌러 주세요. (스토어 출시 전에는 테스트 배포 링크를 이용하세요.)</p>
</body></html>`;
  return new Response(html, {
    headers: { 'content-type': 'text/html; charset=utf-8' },
  });
}

export default {
  async fetch(req) {
    const url = new URL(req.url);
    const p = url.pathname;
    if (p === '/.well-known/apple-app-site-association') return aasa();
    if (p === '/.well-known/assetlinks.json') return assetlinks();
    if (p.startsWith('/e/')) return landing();
    if (p === '/' || p === '/health') {
      return new Response('kcc links ok', { headers: { 'content-type': 'text/plain; charset=utf-8' } });
    }
    return new Response('Not found', { status: 404 });
  },
};
