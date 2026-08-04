// kcc.sidore.org - 유니버설/앱링크 연동파일 + 공유 링크 랜딩.
// 앱 설치 시 OS가 /e/* 링크를 앱으로 가로채므로, 이 랜딩은 미설치/브라우저 폴백용.

// 선행조건: 아래 값을 실제 값으로 교체.
const APPLE_TEAM_ID = 'W6B6ZQQ57S'; // ios/Runner.xcodeproj DEVELOPMENT_TEAM 값
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
  // 디자인: docs/superpowers/specs/2026-08-04-공유링크-랜딩페이지-design.md (B안: 브랜드 히어로형).
  // 목업(kcc-links/mockups/b-brand-hero.html)은 실제 앱 아이콘 PNG를 쓰지만, 이 워커는
  // 빌드 단계 없는 단일 JS 파일이라 무거운 PNG를 내장하지 않고 같은 느낌을 인라인 SVG로 재현.
  const html = `<!doctype html><html lang="ko"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>가톨릭 달력 - 일정 공유</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Song+Myung&family=Pretendard:wght@400;600;700&display=swap" rel="stylesheet">
<style>
* { box-sizing: border-box; }
body {
  margin: 0; min-height: 100vh;
  background: radial-gradient(circle at 50% 0%, #F6F3EC 0%, #EDEBE4 55%, #E7E3D8 100%);
  font-family: 'Pretendard', -apple-system, system-ui, sans-serif;
  color: #3A3630; display: flex; align-items: center; justify-content: center;
}
.wrap { max-width: 420px; width: 100%; padding: 56px 28px 40px; text-align: center; }
.icon-shell {
  display: inline-flex; padding: 14px; border-radius: 32px;
  background: radial-gradient(circle, rgba(46,125,50,0.16), rgba(46,125,50,0) 70%);
  margin-bottom: 8px;
}
.icon { width: 128px; height: 128px; filter: drop-shadow(0 12px 20px rgba(58, 54, 48, 0.22)); }
h1 { font-family: 'Song Myung', serif; font-size: 32px; margin: 22px 0 8px; }
p.tagline { font-size: 15px; color: #857F73; margin: 0 0 26px; }
.divider { display: flex; align-items: center; justify-content: center; gap: 14px; margin: 26px 0; }
.divider .dot { width: 10px; height: 10px; border-radius: 50%; }
.divider .line { height: 1px; width: 32px; background: #D8D3C6; }
.g { background: #2E7D32; } .y { background: #B59410; } .r { background: #C62828; } .v { background: #6A1B9A; }
p.body-text { font-size: 16px; line-height: 1.6; color: #55504A; margin: 0 0 30px; }
.cta {
  display: inline-flex; align-items: center; gap: 8px; padding: 17px 40px; border-radius: 999px;
  background: #2E7D32; color: #fff; font-weight: 700; font-size: 17px; text-decoration: none;
  box-shadow: 0 10px 28px rgba(46, 125, 50, 0.32); transition: transform 0.15s ease;
}
.cta:active { transform: scale(0.96); }
.hint { font-size: 13px; color: #9A948A; margin-top: 22px; line-height: 1.5; }
</style></head>
<body>
<div class="wrap">
  <div class="icon-shell">
    <svg class="icon" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="가톨릭 달력">
      <circle cx="32" cy="10" r="6" fill="#D8CBA3" stroke="#B59410" stroke-width="1.5"/>
      <circle cx="68" cy="10" r="6" fill="#D8CBA3" stroke="#B59410" stroke-width="1.5"/>
      <rect x="4" y="10" width="92" height="86" rx="20" fill="#FBF8F1" stroke="#E7E1D2" stroke-width="1"/>
      <rect x="4" y="10" width="92" height="24" rx="20" fill="#F2ECDC"/>
      <rect x="4" y="26" width="92" height="8" fill="#F2ECDC"/>
      <circle cx="30" cy="60" r="6.5" fill="#2E7D32"/>
      <circle cx="46.5" cy="60" r="6.5" fill="#B59410"/>
      <circle cx="63" cy="60" r="6.5" fill="#C62828"/>
      <circle cx="79.5" cy="60" r="6.5" fill="#6A1B9A"/>
    </svg>
  </div>
  <h1>가톨릭 달력</h1>
  <p class="tagline">전례력과 함께하는 나의 하루</p>
  <div class="divider">
    <span class="line"></span>
    <span class="dot g"></span><span class="dot y"></span><span class="dot r"></span><span class="dot v"></span>
    <span class="line"></span>
  </div>
  <p class="body-text">공유된 일정을 확인하려면<br>가톨릭 달력 앱이 필요합니다.</p>
  <a class="cta" href="#" onclick="location.href=location.href.replace('https://kcc.sidore.org/e/','catholiccalendar://e/');return false;">앱에서 열기 →</a>
  <p class="hint">앱이 없으신가요? 설치 후 이 링크를 다시 눌러 주세요.<br>(스토어 출시 전에는 테스트 배포 링크를 이용하세요.)</p>
</div>
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
