import http from 'node:http';

const port = Number(process.env.API_PORT || 8080);
const host = process.env.API_HOST || '0.0.0.0';
const appEnv = process.env.APP_ENV || 'development';
const workerBaseUrl =
  process.env.CLOUDFLARE_WORKER_BASE_URL ||
  'https://catholic-calendar.sidore.workers.dev';

const startedAt = new Date();

function sendJson(res, status, body, headers = {}) {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    ...headers,
  });
  res.end(payload);
}

function sendText(res, status, body) {
  res.writeHead(status, {
    'content-type': 'text/plain; charset=utf-8',
    'cache-control': 'no-store',
  });
  res.end(body);
}

function calendarUrl(year, month) {
  return `${workerBaseUrl.replace(/\/+$/, '')}/v1/calendar/${year}/${month}`;
}

function parseCalendarPath(pathname) {
  const match = pathname.match(/^\/v1\/calendar\/(\d{4})\/(\d{1,2})$/);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  if (!Number.isInteger(year) || !Number.isInteger(month)) return null;
  if (year < 1900 || year > 2200 || month < 1 || month > 12) return null;
  return { year, month };
}

async function handleCalendar(req, res, year, month) {
  if (req.method !== 'GET') {
    sendJson(res, 405, { error: 'method_not_allowed' }, { allow: 'GET' });
    return;
  }

  const upstream = calendarUrl(year, month);
  try {
    const response = await fetch(upstream, {
      headers: {
        accept: 'application/json',
        'user-agent': 'catholic-calendar-self-hosted-server/0.1.0',
      },
      signal: AbortSignal.timeout(8000),
    });
    const text = await response.text();
    res.writeHead(response.status, {
      'content-type':
        response.headers.get('content-type') ||
        'application/json; charset=utf-8',
      'cache-control': 'no-store',
      'x-upstream-source': 'cloudflare-worker',
    });
    res.end(text);
  } catch (error) {
    sendJson(res, 200, {
      year,
      month,
      available: false,
      error: 'upstream_unavailable',
    });
  }
}

async function handleRequest(req, res) {
  const url = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);

  if (url.pathname === '/' && req.method === 'GET') {
    sendText(res, 200, 'catholic-calendar self-hosted server ok');
    return;
  }

  if (url.pathname === '/health' && req.method === 'GET') {
    sendJson(res, 200, {
      ok: true,
      service: 'catholic-calendar-server-app',
      env: appEnv,
      startedAt: startedAt.toISOString(),
      uptimeSeconds: Math.floor(process.uptime()),
    });
    return;
  }

  const calendar = parseCalendarPath(url.pathname);
  if (calendar) {
    await handleCalendar(req, res, calendar.year, calendar.month);
    return;
  }

  sendJson(res, 404, { error: 'not_found' });
}

const server = http.createServer((req, res) => {
  handleRequest(req, res).catch((error) => {
    console.error('Unhandled request error', error);
    sendJson(res, 500, { error: 'internal_server_error' });
  });
});

server.listen(port, host, () => {
  console.log(`catholic-calendar server listening on ${host}:${port}`);
});

function shutdown(signal) {
  console.log(`Received ${signal}, shutting down`);
  server.close(() => {
    process.exit(0);
  });
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
