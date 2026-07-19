import http from 'node:http';
import pg from 'pg';

const port = Number(process.env.BACKOFFICE_PORT || 3000);
const host = process.env.BACKOFFICE_HOST || '0.0.0.0';
const basePath = normalizeBasePath(process.env.BACKOFFICE_BASE_PATH || '/kcc');
const adminToken = process.env.ADMIN_TOKEN || '';
const apiBaseUrl =
  process.env.API_INTERNAL_BASE_URL ||
  `http://api:${process.env.API_PORT || 8080}/kcc/v1`;

const db = new pg.Pool({
  host: process.env.POSTGRES_HOST || 'db',
  port: Number(process.env.POSTGRES_PORT || 5432),
  database: process.env.POSTGRES_DB,
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD,
});

function normalizeBasePath(value) {
  const trimmed = value.trim().replace(/\/+$/, '');
  if (!trimmed) return '';
  return trimmed.startsWith('/') ? trimmed : `/${trimmed}`;
}

function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function normalizeJsonText(payload) {
  return `${JSON.stringify(payload, null, 2)}\n`;
}

function diffLines(beforeText, afterText) {
  const before = beforeText.split('\n');
  const after = afterText.split('\n');
  const rows = [];
  let i = 0;
  let j = 0;
  let beforeLine = 1;
  let afterLine = 1;

  while (i < before.length || j < after.length) {
    if (i < before.length && j < after.length && before[i] === after[j]) {
      rows.push({
        type: 'same',
        before: before[i],
        after: after[j],
        beforeLine,
        afterLine,
      });
      i += 1;
      j += 1;
      beforeLine += 1;
      afterLine += 1;
      continue;
    }

    const nextBeforeMatchesAfter =
      i + 1 < before.length && j < after.length && before[i + 1] === after[j];
    const beforeMatchesNextAfter =
      i < before.length && j + 1 < after.length && before[i] === after[j + 1];

    if (nextBeforeMatchesAfter) {
      rows.push({
        type: 'removed',
        before: before[i],
        after: '',
        beforeLine,
        afterLine: '',
      });
      i += 1;
      beforeLine += 1;
      continue;
    }

    if (beforeMatchesNextAfter) {
      rows.push({
        type: 'added',
        before: '',
        after: after[j],
        beforeLine: '',
        afterLine,
      });
      j += 1;
      afterLine += 1;
      continue;
    }

    if (i < before.length && j < after.length) {
      rows.push({
        type: 'changed',
        before: before[i],
        after: after[j],
        beforeLine,
        afterLine,
      });
      i += 1;
      j += 1;
      beforeLine += 1;
      afterLine += 1;
      continue;
    }

    if (i < before.length) {
      rows.push({
        type: 'removed',
        before: before[i],
        after: '',
        beforeLine,
        afterLine: '',
      });
      i += 1;
      beforeLine += 1;
      continue;
    }

    rows.push({
      type: 'added',
      before: '',
      after: after[j],
      beforeLine: '',
      afterLine,
    });
    j += 1;
    afterLine += 1;
  }

  return rows;
}

function sendHtml(res, status, body) {
  res.writeHead(status, {
    'content-type': 'text/html; charset=utf-8',
    'cache-control': 'no-store',
  });
  res.end(body);
}

function sendJson(res, status, body) {
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
  });
  res.end(JSON.stringify(body));
}

function redirect(res, location) {
  res.writeHead(303, { location });
  res.end();
}

function isAuthorized(req) {
  if (!adminToken) return true;

  const header = req.headers.authorization || '';
  if (!header.startsWith('Basic ')) return false;

  const decoded = Buffer.from(header.slice('Basic '.length), 'base64').toString(
    'utf8',
  );
  const separator = decoded.indexOf(':');
  const username = separator >= 0 ? decoded.slice(0, separator) : decoded;
  const password = separator >= 0 ? decoded.slice(separator + 1) : '';
  return username === 'admin' && password === adminToken;
}

function requireAuth(req, res) {
  if (isAuthorized(req)) return true;

  res.writeHead(401, {
    'www-authenticate': 'Basic realm="KCC Backoffice"',
    'content-type': 'text/plain; charset=utf-8',
  });
  res.end('Authentication required');
  return false;
}

async function readForm(req) {
  const chunks = [];
  for await (const chunk of req) {
    chunks.push(chunk);
  }
  return new URLSearchParams(Buffer.concat(chunks).toString('utf8'));
}

function parseYearMonth(params) {
  const year = Number(params.get('year'));
  const month = Number(params.get('month'));
  if (!Number.isInteger(year) || year < 1900 || year > 2200) {
    throw new Error('invalid_year');
  }
  if (!Number.isInteger(month) || month < 1 || month > 12) {
    throw new Error('invalid_month');
  }
  return { year, month };
}

async function listCalendarMonths() {
  const result = await db.query(`
    SELECT
      year,
      month,
      available,
      source,
      fetched_at,
      updated_at,
      jsonb_array_length(COALESCE(payload_json->'days', '[]'::jsonb)) AS day_count
    FROM calendar_months
    ORDER BY year DESC, month DESC
  `);
  return result.rows;
}

async function deleteCalendarMonth(year, month) {
  await db.query('DELETE FROM calendar_months WHERE year = $1 AND month = $2', [
    year,
    month,
  ]);
}

async function getCalendarMonth(year, month) {
  const result = await db.query(
    `
      SELECT year, month, available, source, payload_json, fetched_at, updated_at
      FROM calendar_months
      WHERE year = $1 AND month = $2
    `,
    [year, month],
  );
  return result.rows[0] || null;
}

async function updateCalendarMonth(year, month, payload) {
  await db.query(
    `
      UPDATE calendar_months
      SET
        available = $3,
        source = 'manual',
        payload_json = $4::jsonb,
        updated_at = now()
      WHERE year = $1 AND month = $2
    `,
    [year, month, payload.available !== false, JSON.stringify(payload)],
  );
}

async function refreshCalendarMonth(year, month) {
  await deleteCalendarMonth(year, month);
  const url = `${apiBaseUrl.replace(/\/+$/, '')}/calendar/${year}/${month}`;
  const response = await fetch(url, { signal: AbortSignal.timeout(10000) });
  if (!response.ok) {
    throw new Error(`refresh_failed_${response.status}`);
  }
  await response.arrayBuffer();
}

function layout(title, content) {
  const authNote = adminToken
    ? 'Basic Auth: admin / ADMIN_TOKEN'
    : 'ADMIN_TOKEN is not set. Local access only.';

  return `<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHtml(title)}</title>
  <style>
    :root {
      color-scheme: light;
      --bg: #f6f7f8;
      --surface: #ffffff;
      --line: #d8dde3;
      --text: #17202a;
      --muted: #66717f;
      --primary: #0a6b58;
      --danger: #b42318;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: var(--bg);
      color: var(--text);
      font: 14px/1.5 system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    header {
      background: var(--surface);
      border-bottom: 1px solid var(--line);
      padding: 18px 24px;
    }
    main {
      max-width: 1120px;
      margin: 0 auto;
      padding: 24px;
    }
    h1 {
      margin: 0;
      font-size: 22px;
      line-height: 1.2;
    }
    .sub {
      margin-top: 6px;
      color: var(--muted);
    }
    .toolbar {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      align-items: end;
      margin-bottom: 18px;
      padding: 16px;
      background: var(--surface);
      border: 1px solid var(--line);
      border-radius: 8px;
    }
    label {
      display: grid;
      gap: 4px;
      color: var(--muted);
      font-size: 12px;
    }
    input {
      width: 110px;
      min-height: 36px;
      border: 1px solid var(--line);
      border-radius: 6px;
      padding: 7px 9px;
      color: var(--text);
      background: #fff;
      font: inherit;
    }
    button, .button {
      min-height: 36px;
      border: 1px solid var(--primary);
      border-radius: 6px;
      padding: 7px 11px;
      background: var(--primary);
      color: #fff;
      font: inherit;
      text-decoration: none;
      cursor: pointer;
    }
    a.button {
      display: inline-flex;
      align-items: center;
    }
    .button.secondary {
      background: #fff;
      color: var(--primary);
    }
    button.secondary {
      background: #fff;
      color: var(--primary);
    }
    button.danger {
      border-color: var(--danger);
      background: var(--danger);
    }
    table {
      width: 100%;
      border-collapse: collapse;
      background: var(--surface);
      border: 1px solid var(--line);
      border-radius: 8px;
      overflow: hidden;
    }
    th, td {
      border-bottom: 1px solid var(--line);
      padding: 10px 12px;
      text-align: left;
      vertical-align: middle;
      white-space: nowrap;
    }
    th {
      color: var(--muted);
      font-size: 12px;
      font-weight: 700;
      background: #fbfbfc;
    }
    tr:last-child td { border-bottom: 0; }
    .actions {
      display: flex;
      gap: 8px;
      justify-content: flex-end;
    }
    .empty {
      background: var(--surface);
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 22px;
      color: var(--muted);
    }
    .message {
      margin-bottom: 14px;
      color: var(--primary);
      font-weight: 700;
    }
    .editor {
      display: grid;
      gap: 14px;
      padding: 16px;
      background: var(--surface);
      border: 1px solid var(--line);
      border-radius: 8px;
    }
    .editor textarea {
      width: 100%;
      min-height: 62vh;
      resize: vertical;
      border: 1px solid var(--line);
      border-radius: 6px;
      padding: 12px;
      color: var(--text);
      background: #fff;
      font: 13px/1.45 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
      tab-size: 2;
    }
    .editor-actions {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      justify-content: space-between;
      align-items: center;
    }
    .warning {
      color: var(--danger);
      font-weight: 700;
    }
    .diff-wrap {
      display: grid;
      gap: 14px;
    }
    .diff-table {
      table-layout: fixed;
    }
    .diff-table td {
      white-space: pre-wrap;
      overflow-wrap: anywhere;
      vertical-align: top;
      font: 12px/1.45 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    }
    .diff-table .line-no {
      width: 72px;
      color: var(--muted);
      text-align: right;
      user-select: none;
    }
    .diff-added td {
      background: #e9f8f0;
    }
    .diff-removed td {
      background: #fff0ee;
    }
    .diff-changed td {
      background: #fff8db;
    }
    .hidden-payload {
      display: none;
    }
    @media (max-width: 760px) {
      main { padding: 16px; }
      table { display: block; overflow-x: auto; }
    }
  </style>
</head>
<body>
  <header>
    <h1>KCC Backoffice</h1>
    <div class="sub">${escapeHtml(authNote)}</div>
  </header>
  <main>${content}</main>
</body>
</html>`;
}

function monthRows(rows) {
  if (rows.length === 0) {
    return '<div class="empty">저장된 전례력 월별 캐시가 없습니다.</div>';
  }

  const cells = rows
    .map((row) => {
      const year = Number(row.year);
      const month = Number(row.month);
      return `<tr>
        <td>${year}</td>
        <td>${month}</td>
        <td>${escapeHtml(row.source)}</td>
        <td>${row.available ? 'yes' : 'no'}</td>
        <td>${Number(row.day_count || 0)}</td>
        <td>${escapeHtml(new Date(row.fetched_at).toLocaleString('ko-KR'))}</td>
        <td>${escapeHtml(new Date(row.updated_at).toLocaleString('ko-KR'))}</td>
        <td>
          <div class="actions">
            <a class="button secondary" href="${basePath}/calendar/edit?year=${year}&month=${month}">수정</a>
            <form method="post" action="${basePath}/calendar/refresh">
              <input type="hidden" name="year" value="${year}">
              <input type="hidden" name="month" value="${month}">
              <button class="secondary" type="submit">재갱신</button>
            </form>
            <form method="post" action="${basePath}/calendar/delete">
              <input type="hidden" name="year" value="${year}">
              <input type="hidden" name="month" value="${month}">
              <button class="danger" type="submit">삭제</button>
            </form>
          </div>
        </td>
      </tr>`;
    })
    .join('');

  return `<table>
    <thead>
      <tr>
        <th>연도</th>
        <th>월</th>
        <th>출처</th>
        <th>사용 가능</th>
        <th>일수</th>
        <th>가져온 시각</th>
        <th>수정 시각</th>
        <th></th>
      </tr>
    </thead>
    <tbody>${cells}</tbody>
  </table>`;
}

async function handleIndex(req, res, url) {
  const rows = await listCalendarMonths();
  const message = url.searchParams.get('message');
  const content = `
    ${message ? `<div class="message">${escapeHtml(message)}</div>` : ''}
    <form class="toolbar" method="post" action="${basePath}/calendar/refresh">
      <label>연도 <input name="year" inputmode="numeric" value="2026"></label>
      <label>월 <input name="month" inputmode="numeric" value="7"></label>
      <button type="submit">캐시 생성/재갱신</button>
    </form>
    ${monthRows(rows)}
  `;
  sendHtml(res, 200, layout('KCC Backoffice', content));
}

function renderEditForm(year, month, payload, message = '') {
  const draftKey = `kcc-calendar-editor-${year}-${month}`;
  const content = `
    <form class="editor" method="post" action="${basePath}/calendar/edit/preview">
      <input type="hidden" name="year" value="${year}">
      <input type="hidden" name="month" value="${month}">
      <div>
        <h2>${year}년 ${month}월 JSON 수정</h2>
        <div class="sub">먼저 JSON 문법을 검증하고 diff를 확인한 뒤, 최종 확인을 눌러야 저장됩니다. 저장하면 이 월의 출처가 <strong>manual</strong>로 바뀝니다.</div>
      </div>
      ${message ? `<div class="message">${escapeHtml(message)}</div>` : ''}
      <textarea id="payload-editor" name="payload" spellcheck="false">${escapeHtml(payload)}</textarea>
      <div class="editor-actions">
        <a class="button secondary" data-clear-draft="true" href="${basePath}">목록으로</a>
        <div class="warning">JSON 문법이 틀리면 diff 확인 단계로 넘어가지 않습니다.</div>
        <button type="submit">JSON 검증 및 diff 확인</button>
      </div>
    </form>
    <script>
      (() => {
        const key = ${JSON.stringify(draftKey)};
        const editor = document.getElementById('payload-editor');
        const draft = sessionStorage.getItem(key);
        if (draft !== null && draft !== editor.value) {
          editor.value = draft;
        }
        editor.addEventListener('input', () => {
          sessionStorage.setItem(key, editor.value);
        });
        document.querySelectorAll('[data-clear-draft="true"]').forEach((node) => {
          node.addEventListener('click', () => sessionStorage.removeItem(key));
        });
      })();
    </script>
  `;
  return layout('KCC Backoffice', content);
}

async function handleEdit(req, res, url) {
  const { year, month } = parseYearMonth(url.searchParams);
  const row = await getCalendarMonth(year, month);
  if (!row) {
    sendHtml(
      res,
      404,
      layout('KCC Backoffice', '<div class="empty">캐시를 찾을 수 없습니다.</div>'),
    );
    return;
  }

  const payload = normalizeJsonText(row.payload_json);
  sendHtml(res, 200, renderEditForm(year, month, payload));
}

async function handleEditRestore(req, res) {
  const form = await readForm(req);
  const { year, month } = parseYearMonth(form);
  const payload = form.get('payload') || '';
  sendHtml(
    res,
    200,
    renderEditForm(
      year,
      month,
      payload,
      'diff 확인 화면에서 돌아왔습니다. 입력하던 내용은 아직 저장되지 않았습니다.',
    ),
  );
}

function renderDiffTable(rows) {
  const visibleRows = rows.filter((row) => row.type !== 'same');
  if (visibleRows.length === 0) {
    return '<div class="empty">변경된 내용이 없습니다.</div>';
  }

  const body = visibleRows
    .map((row) => {
      const klass = `diff-${row.type}`;
      const marker =
        row.type === 'added' ? '+' : row.type === 'removed' ? '-' : '~';
      return `<tr class="${klass}">
        <td class="line-no">${escapeHtml(row.beforeLine)}</td>
        <td>${marker}</td>
        <td>${escapeHtml(row.before)}</td>
        <td class="line-no">${escapeHtml(row.afterLine)}</td>
        <td>${escapeHtml(row.after)}</td>
      </tr>`;
    })
    .join('');

  return `<table class="diff-table">
    <thead>
      <tr>
        <th>이전 줄</th>
        <th></th>
        <th>이전 값</th>
        <th>수정 줄</th>
        <th>수정 값</th>
      </tr>
    </thead>
    <tbody>${body}</tbody>
  </table>`;
}

async function handleEditPreview(req, res) {
  const form = await readForm(req);
  const { year, month } = parseYearMonth(form);
  const row = await getCalendarMonth(year, month);
  if (!row) {
    sendHtml(
      res,
      404,
      layout('KCC Backoffice', '<div class="empty">캐시를 찾을 수 없습니다.</div>'),
    );
    return;
  }

  const payloadText = form.get('payload') || '';
  let payload;
  try {
    payload = JSON.parse(payloadText);
  } catch (error) {
    sendHtml(
      res,
      400,
      layout(
        'KCC Backoffice',
        `<div class="empty">JSON 문법 오류로 저장하지 않았습니다: ${escapeHtml(error.message)}</div>
        <form method="post" action="${basePath}/calendar/edit/restore">
          <input type="hidden" name="year" value="${year}">
          <input type="hidden" name="month" value="${month}">
          <textarea class="hidden-payload" name="payload">${escapeHtml(payloadText)}</textarea>
          <button class="secondary" type="submit">수정 화면으로 돌아가기</button>
        </form>`,
      ),
    );
    return;
  }

  const beforeText = normalizeJsonText(row.payload_json);
  const afterText = normalizeJsonText(payload);
  const draftKey = `kcc-calendar-editor-${year}-${month}`;
  const rows = diffLines(beforeText, afterText);
  const hasChanges = rows.some((row) => row.type !== 'same');
  const content = `
    <div class="diff-wrap">
      <div class="editor">
        <div>
          <h2>${year}년 ${month}월 수정 diff 확인</h2>
          <div class="sub">JSON 문법 검증을 통과했습니다. 아래 변경 내용을 확인한 뒤 최종 저장을 눌러야 DB에 반영됩니다.</div>
        </div>
        ${renderDiffTable(rows)}
        <div class="editor-actions">
          <form method="post" action="${basePath}/calendar/edit/restore">
            <input type="hidden" name="year" value="${year}">
            <input type="hidden" name="month" value="${month}">
            <textarea class="hidden-payload" name="payload">${escapeHtml(afterText)}</textarea>
            <button class="secondary" type="submit">수정 화면으로 돌아가기</button>
          </form>
          <form method="post" action="${basePath}/calendar/edit/commit">
            <input type="hidden" name="year" value="${year}">
            <input type="hidden" name="month" value="${month}">
            <textarea class="hidden-payload" name="payload">${escapeHtml(afterText)}</textarea>
            <button data-clear-draft="true" type="submit"${hasChanges ? '' : ' disabled'}>최종 저장</button>
          </form>
        </div>
      </div>
    </div>
    <script>
      (() => {
        const key = ${JSON.stringify(draftKey)};
        document.querySelectorAll('[data-clear-draft="true"]').forEach((node) => {
          node.addEventListener('click', () => sessionStorage.removeItem(key));
        });
      })();
    </script>
  `;
  sendHtml(res, 200, layout('KCC Backoffice', content));
}

async function handlePost(req, res, action) {
  const form = await readForm(req);
  const { year, month } = parseYearMonth(form);

  if (action === 'delete') {
    await deleteCalendarMonth(year, month);
    redirect(res, `${basePath}?message=${encodeURIComponent('캐시를 삭제했습니다.')}`);
    return;
  }

  if (action === 'refresh') {
    await refreshCalendarMonth(year, month);
    redirect(res, `${basePath}?message=${encodeURIComponent('캐시를 재갱신했습니다.')}`);
    return;
  }

  if (action === 'edit') {
    const payloadText = form.get('payload') || '';
    let payload;
    try {
      payload = JSON.parse(payloadText);
    } catch (error) {
      sendHtml(
        res,
        400,
        layout(
          'KCC Backoffice',
          `<div class="empty">JSON 문법 오류로 저장하지 않았습니다: ${escapeHtml(error.message)}</div>
          <form method="post" action="${basePath}/calendar/edit/restore">
            <input type="hidden" name="year" value="${year}">
            <input type="hidden" name="month" value="${month}">
            <textarea class="hidden-payload" name="payload">${escapeHtml(payloadText)}</textarea>
            <button class="secondary" type="submit">수정 화면으로 돌아가기</button>
          </form>`,
        ),
      );
      return;
    }

    await updateCalendarMonth(year, month, payload);
    redirect(res, `${basePath}?message=${encodeURIComponent('수동 수정 내용을 최종 저장했습니다.')}`);
    return;
  }

  sendJson(res, 404, { error: 'not_found' });
}

async function handleRequest(req, res) {
  const url = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);
  if (url.pathname === '/health' && req.method === 'GET') {
    await db.query('SELECT 1');
    sendJson(res, 200, { ok: true, service: 'catholic-calendar-backoffice' });
    return;
  }

  if (!requireAuth(req, res)) return;

  if ((url.pathname === '/' || url.pathname === basePath) && req.method === 'GET') {
    await handleIndex(req, res, url);
    return;
  }

  if (url.pathname === `${basePath}/calendar/edit` && req.method === 'GET') {
    await handleEdit(req, res, url);
    return;
  }

  if (url.pathname === `${basePath}/calendar/delete` && req.method === 'POST') {
    await handlePost(req, res, 'delete');
    return;
  }

  if (url.pathname === `${basePath}/calendar/edit/preview` && req.method === 'POST') {
    await handleEditPreview(req, res);
    return;
  }

  if (url.pathname === `${basePath}/calendar/edit/restore` && req.method === 'POST') {
    await handleEditRestore(req, res);
    return;
  }

  if (url.pathname === `${basePath}/calendar/edit/commit` && req.method === 'POST') {
    await handlePost(req, res, 'edit');
    return;
  }

  if (url.pathname === `${basePath}/calendar/refresh` && req.method === 'POST') {
    await handlePost(req, res, 'refresh');
    return;
  }

  sendJson(res, 404, { error: 'not_found' });
}

const server = http.createServer((req, res) => {
  handleRequest(req, res).catch((error) => {
    console.error('Unhandled backoffice error', error);
    sendHtml(
      res,
      500,
      layout(
        'KCC Backoffice Error',
        `<div class="empty">오류가 발생했습니다: ${escapeHtml(error.message)}</div>`,
      ),
    );
  });
});

server.listen(port, host, () => {
  console.log(`catholic-calendar backoffice listening on ${host}:${port}`);
});

function shutdown(signal) {
  console.log(`Received ${signal}, shutting down`);
  server.close(() => {
    db.end()
      .catch((error) => {
        console.error('Failed to close database pool', error);
      })
      .finally(() => {
        process.exit(0);
      });
  });
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
