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

  if (url.pathname === `${basePath}/calendar/delete` && req.method === 'POST') {
    await handlePost(req, res, 'delete');
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
