// kcc.sidore.org - 유니버설/앱링크 연동파일 + 공유 링크 랜딩.
// 앱 설치 시 OS가 /e/* 링크를 앱으로 가로채므로, 이 랜딩은 미설치/브라우저 폴백용.

// 선행조건: 아래 값을 실제 값으로 교체.
const APPLE_TEAM_ID = 'W6B6ZQQ57S'; // ios/Runner.xcodeproj DEVELOPMENT_TEAM 값
const IOS_BUNDLE_ID = 'com.sidore.catholiccalendar';
const ANDROID_PACKAGE = 'com.sidore.catholiccalendar';
const IOS_APP_STORE_URL = 'https://apps.apple.com/app/id6791044471';
const ANDROID_PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=com.sidore.catholiccalendar';
const ANDROID_SHA256 = [
  'AC:FC:40:59:6B:0C:64:9C:E5:2B:11:6D:B1:C1:61:57:54:04:24:0C:7B:0F:85:1D:EC:C0:DC:6F:60:A9:82:C0',
  '86:50:DA:AB:FF:D0:67:20:3C:3C:75:F3:A6:24:66:EB:BB:75:5B:7D:7A:78:EF:B6:23:82:6B:E7:90:82:E4:83',
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

function landing(req) {
  // 미설치/브라우저 폴백: 앱에서 열기 시도 + 스토어 안내(스토어 미출시 전엔 안내 문구).
  // 디자인: docs/superpowers/specs/2026-08-04-공유링크-랜딩페이지-design.md (A안: 미니멀 카드형).
  // 목업(kcc-links/mockups/a-minimal-card.html)은 실제 앱 아이콘 PNG를 쓰지만, 이 워커는
  // 빌드 단계 없는 단일 JS 파일이라 무거운 PNG를 내장하지 않고 같은 느낌을 인라인 SVG로 재현.
  const url = new URL(req.url);
  const userAgent = req.headers.get('user-agent') || '';
  const initialStoreUrl = /iPad|iPhone|iPod/.test(userAgent)
    ? IOS_APP_STORE_URL
    : ANDROID_PLAY_STORE_URL;
  const deepLink = `catholiccalendar://${url.pathname.replace(/^\//, '')}${url.search}`;
  const html = `<!doctype html><html lang="ko"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>가톨릭 달력 - 일정 공유</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Song+Myung&family=Pretendard:wght@400;600;700&display=swap" rel="stylesheet">
<style>
* { box-sizing: border-box; }
body {
  margin: 0;
  min-height: 100vh;
  background: #EDEBE4;
  font-family: 'Pretendard', -apple-system, system-ui, sans-serif;
  color: #3A3630;
  display: flex;
  flex-direction: column;
  align-items: center;
}
.stripe {
  height: 6px;
  width: 100%;
  background: linear-gradient(90deg, #2E7D32, #B59410, #C62828, #6A1B9A);
}
.wrap {
  flex: 1;
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 32px 20px;
}
.card {
  background: #FFFFFF;
  border-radius: 28px;
  max-width: 380px;
  width: 100%;
  padding: 36px 28px 32px;
  text-align: center;
  box-shadow: 0 12px 40px rgba(58, 54, 48, 0.12), 0 2px 8px rgba(58, 54, 48, 0.06);
}
.icon {
  width: 88px;
  height: 88px;
  border-radius: 22px;
  box-shadow: 0 6px 18px rgba(58, 54, 48, 0.18);
  margin-bottom: 18px;
}
.dots { display: flex; justify-content: center; gap: 10px; margin-bottom: 20px; }
.dot { width: 8px; height: 8px; border-radius: 50%; }
.g { background: #2E7D32; } .y { background: #B59410; } .r { background: #C62828; } .v { background: #6A1B9A; }
h1 {
  font-family: 'Song Myung', serif;
  font-size: 26px;
  margin: 0 0 10px;
  letter-spacing: 0.02em;
}
p.body-text {
  font-size: 15px;
  line-height: 1.55;
  color: #6B655C;
  margin: 0 0 26px;
}
.cta {
  display: block;
  width: 100%;
  padding: 15px 0;
  border-radius: 999px;
  background: #2E7D32;
  color: #fff;
  font-weight: 700;
  font-size: 16px;
  text-decoration: none;
  box-shadow: 0 8px 20px rgba(46, 125, 50, 0.3);
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.cta:active { transform: scale(0.97); box-shadow: 0 4px 10px rgba(46, 125, 50, 0.25); }
.hint { font-size: 13px; color: #9A948A; margin-top: 18px; line-height: 1.5; }
</style></head>
<body>
<div class="stripe"></div>
<div class="wrap">
  <div class="card">
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
    <div class="dots">
    <span class="dot g"></span><span class="dot y"></span><span class="dot r"></span><span class="dot v"></span>
    </div>
    <h1>가톨릭 달력</h1>
    <p class="body-text">공유된 일정을 확인하려면<br>가톨릭 달력 앱이 필요합니다.</p>
    <a class="cta" id="open-app" href="${initialStoreUrl}">앱에서 열기</a>
    <p class="hint">앱이 없으면 사용 중인 기기에 맞는<br>스토어 페이지로 이동합니다.</p>
  </div>
</div>
<script>
(() => {
  const deepLink = ${JSON.stringify(deepLink)};
  const iosStoreUrl = ${JSON.stringify(IOS_APP_STORE_URL)};
  const androidStoreUrl = ${JSON.stringify(ANDROID_PLAY_STORE_URL)};
  const ua = navigator.userAgent || '';
  const isIOS = /iPad|iPhone|iPod/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  const isAndroid = /Android/.test(ua);
  const storeUrl = isIOS ? iosStoreUrl : isAndroid ? androidStoreUrl : androidStoreUrl;
  const button = document.getElementById('open-app');
  if (!button) return;

  button.href = storeUrl;

  button.addEventListener('click', (event) => {
    event.preventDefault();
    let hidden = false;
    const markHidden = () => { hidden = true; };
    const cleanup = () => {
      document.removeEventListener('visibilitychange', onVisibilityChange);
      window.removeEventListener('pagehide', markHidden);
    };
    const onVisibilityChange = () => {
      if (document.hidden) markHidden();
    };

    document.addEventListener('visibilitychange', onVisibilityChange);
    window.addEventListener('pagehide', markHidden);

    window.location.href = deepLink;
    window.setTimeout(() => {
      cleanup();
      if (!hidden) window.location.href = storeUrl;
    }, 1200);
  });
})();
</script>
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
    if (p.startsWith('/e/')) return landing(req);
    if (p === '/' || p === '/health') {
      return new Response('kcc links ok', { headers: { 'content-type': 'text/plain; charset=utf-8' } });
    }
    return new Response('Not found', { status: 404 });
  },
};
