// Страница анализа SonarQube для docker_conf: проекты из SonarQube и запуски со страницы, выбор папки, запуск
// analyze.sh (несколько сразу), живой лог, статус обработки в SonarQube и ссылка на отчёт.
// Одна страница (public/index.html) + JSON API ниже.
// Диски ПК видны как /host/<диск>/... (docker-compose.yml), история запусков с логами - в /data/runs.
'use strict';

const express = require('express');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const PORT = Number(process.env.PORT || 8080);
const ROOT = '/host';
const RUNS = path.join(process.env.DATA_DIR || '/data', 'runs');
const TOKEN_FILE = process.env.TOKEN_FILE || '/data/token';
const UI_TOKEN_FILE = process.env.UI_TOKEN_FILE || '/data/ui-token';
const SONAR_URL = process.env.SONAR_URL || 'http://sonarqube:9000';
const SONAR_PUBLIC_URL = process.env.SONAR_PUBLIC_URL || 'http://localhost:9010';
const KEEP_RUNS = 10; // запусков на проект (папку)

fs.mkdirSync(RUNS, { recursive: true });

function httpError(status, message) { const e = new Error(message); e.status = status; return e; }
const wrap = (fn) => (req, res, next) => Promise.resolve(fn(req, res)).catch(next);

// ---------- папки ----------
// Путь только внутри /host, без .. и симлинков наружу
function safePath(p) {
  const abs = path.posix.resolve(ROOT, String(p || ROOT).replace(/\\/g, '/'));
  if (abs !== ROOT && !abs.startsWith(ROOT + '/')) throw httpError(400, 'Путь вне дисков ПК: ' + p);
  return abs;
}
function buildTool(dir) {
  const has = (f) => fs.existsSync(path.join(dir, f));
  if (has('pom.xml')) return 'maven';
  if (has('build.gradle') || has('build.gradle.kts') || has('settings.gradle') || has('settings.gradle.kts')) return 'gradle';
  return null;
}
const SKIP = new Set(['node_modules', 'target', 'build', 'System Volume Information']);
const BUILD_FILES = ['pom.xml', 'build.gradle', 'build.gradle.kts', 'settings.gradle', 'settings.gradle.kts'];
// Диски ПК подключены через общий доступ к файлам Docker Desktop - каждое обращение медленное. Поэтому подпапки
// помечаются как проекты одним чтением каждой (не пятью проверками), параллельно, и только если их немного.
const DETECT_MAX = 300;
const LIST_MAX = 1000;
async function toolOf(dir) {
  try {
    const names = new Set(await fs.promises.readdir(dir));
    if (names.has('pom.xml')) return 'maven';
    return BUILD_FILES.some((f) => names.has(f)) ? 'gradle' : null;
  } catch { return null; }
}
async function mapLimited(items, limit, fn) {
  const out = new Array(items.length);
  let i = 0;
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (i < items.length) { const k = i++; out[k] = await fn(items[k]); }
  }));
  return out;
}

// ---------- настройки (меняются на странице) ----------
const SETTINGS_FILE = path.join(process.env.DATA_DIR || '/data', 'settings.json');
const DEFAULT_SETTINGS = { maxParallel: 3 };
function loadSettings() {
  try { return { ...DEFAULT_SETTINGS, ...JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf8')) }; } catch { return { ...DEFAULT_SETTINGS }; }
}

// ---------- запуски ----------
// run: { id, path, jdk, tests, key, status: running|sent|failed|stopped|interrupted, started, finished,
//        report: { dashboardUrl, ceTaskId, projectKey }, ce: PENDING|IN_PROGRESS|SUCCESS|FAILED|CANCELED, gate: OK|ERROR }
// Анализы разных папок идут одновременно (не больше maxParallel); одну папку дважды сразу не запустить.
const active = new Map(); // id -> { run, proc, clients:Set<res> }
const runFile = (id, ext) => path.join(RUNS, `${id}.${ext}`);
const saveRun = (run) => fs.writeFileSync(runFile(run.id, 'json'), JSON.stringify(run, null, 1));
function loadRuns() {
  return fs.readdirSync(RUNS).filter((f) => f.endsWith('.json'))
    .map((f) => { try { return JSON.parse(fs.readFileSync(path.join(RUNS, f), 'utf8')); } catch { return null; } })
    .filter(Boolean).sort((a, b) => b.id.localeCompare(a.id));
}
const removeRun = (id) => { for (const ext of ['json', 'log']) fs.rmSync(runFile(id, ext), { force: true }); };
function pruneRuns() {
  const seen = {};
  for (const run of loadRuns()) {
    seen[run.path] = (seen[run.path] || 0) + 1;
    if (seen[run.path] > KEEP_RUNS) removeRun(run.id);
  }
}
// Запуск, оборванный перезапуском контейнера
for (const run of loadRuns()) if (run.status === 'running') { run.status = 'interrupted'; saveRun(run); }

function send(res, event, data) { res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`); }

// report-task.txt пишет сканер: ссылка на отчёт и id задачи обработки в SonarQube
function readReport(run) {
  for (const sub of ['target/sonar', 'build/sonar', '.scannerwork']) {
    const f = path.join(run.path, sub, 'report-task.txt');
    try {
      if (fs.statSync(f).mtimeMs < Date.parse(run.started)) continue;
      const props = Object.fromEntries(fs.readFileSync(f, 'utf8').split(/\r?\n/)
        .map((l) => l.split(/=(.*)/s)).filter((kv) => kv.length > 1));
      return { dashboardUrl: props.dashboardUrl, ceTaskId: props.ceTaskId, projectKey: props.projectKey };
    } catch { /* нет файла */ }
  }
  return null;
}

// Чтение - токеном страницы (devstack-ui), если его ещё нет - токеном анализа
async function sonarApi(apiPath) {
  let token;
  try { token = fs.readFileSync(UI_TOKEN_FILE, 'utf8').trim(); } catch { token = fs.readFileSync(TOKEN_FILE, 'utf8').trim(); }
  const r = await fetch(SONAR_URL + apiPath, { headers: { Authorization: 'Basic ' + Buffer.from(token + ':').toString('base64') } });
  if (!r.ok) throw new Error(`SonarQube ${apiPath}: HTTP ${r.status}`);
  return r.json();
}

// После отправки отчёта SonarQube обрабатывает его (Compute Engine) - следим до конца, затем Quality Gate
async function followCe(run) {
  for (let i = 0; i < 600 && run.report && run.report.ceTaskId; i++) {
    try {
      const { task } = await sonarApi(`/api/ce/task?id=${encodeURIComponent(run.report.ceTaskId)}`);
      if (task.status !== run.ce) { run.ce = task.status; saveRun(run); }
      if (['SUCCESS', 'FAILED', 'CANCELED'].includes(task.status)) {
        if (task.status === 'SUCCESS' && task.analysisId) {
          const { projectStatus } = await sonarApi(`/api/qualitygates/project_status?analysisId=${encodeURIComponent(task.analysisId)}`);
          run.gate = projectStatus.status;
          saveRun(run);
        }
        return;
      }
    } catch (e) { console.error(e.message); }
    await new Promise((r) => setTimeout(r, 2000));
  }
}

function startRun({ path: dir, tests, jdk, key }) {
  const abs = safePath(dir);
  if (!fs.existsSync(abs) || !fs.statSync(abs).isDirectory()) throw httpError(400, 'Папка не найдена: ' + abs);
  if (!buildTool(abs)) throw httpError(400, 'В папке нет pom.xml или build.gradle - нужна корневая папка Maven- или Gradle-проекта');
  if ([...active.values()].some((a) => a.run.path === abs)) throw httpError(409, 'Эта папка уже анализируется - дождитесь окончания или остановите анализ');
  const { maxParallel } = loadSettings();
  if (active.size >= maxParallel) throw httpError(409, `Одновременно идут ${active.size} анализа - это предел (меняется в настройках вверху страницы)`);
  jdk = String(jdk || '21').trim();
  if (!/^\d{1,2}$/.test(jdk)) throw httpError(400, 'JDK - номер версии: 8, 11, 17, 21...');
  key = String(key || '').trim();
  if (key && !/^[\w.:-]+$/.test(key)) throw httpError(400, 'Ключ проекта: латиница, цифры, - _ . :');

  const run = {
    id: new Date().toISOString().replace(/[:.]/g, '-'), path: abs, jdk, tests: tests !== false, key: key || null,
    status: 'running', started: new Date().toISOString(),
  };
  saveRun(run);
  const args = ['/app/analyze.sh', abs, jdk];
  if (!run.tests) args.push('notests');
  if (key) args.push(key);
  const log = fs.createWriteStream(runFile(run.id, 'log'));
  const proc = spawn('sh', args, { env: process.env });
  const entry = { run, proc, clients: new Set() };
  active.set(run.id, entry);
  const out = (chunk) => { const s = chunk.toString(); log.write(s); for (const res of entry.clients) send(res, 'log', s); };
  proc.stdout.on('data', out);
  proc.stderr.on('data', out);
  proc.on('close', (code) => {
    log.end();
    run.finished = new Date().toISOString();
    run.report = readReport(run);
    run.status = run.stopped ? 'stopped' : code === 0 && run.report ? 'sent' : 'failed';
    delete run.stopped;
    saveRun(run);
    for (const res of entry.clients) { send(res, 'end', run); res.end(); }
    active.delete(run.id);
    pruneRuns();
    if (run.status === 'sent') followCe(run);
  });
  return run;
}

// ---------- проекты: всё из SonarQube + запуски со страницы ----------
// Запуск относится к проекту по ключу (из отчёта или заданному); запуск без ключа (упал до отправки) - по папке:
// к проекту, ключ которого известен по другим запускам этой папки, иначе - отдельной строкой с именем папки.
function withProjects(runs) {
  const keyByPath = new Map();
  for (const r of [...runs].reverse()) { const k = (r.report && r.report.projectKey) || r.key; if (k) keyByPath.set(r.path, k); }
  return runs.map((r) => ({ ...r, project: (r.report && r.report.projectKey) || r.key || keyByPath.get(r.path) || 'path:' + r.path }));
}
const METRICS = 'alert_status,bugs,vulnerabilities,code_smells,security_hotspots,coverage,duplicated_lines_density,ncloc';
async function sonarProjects() {
  const { components } = await sonarApi('/api/components/search_projects?ps=500&f=analysisDate');
  const measures = {};
  for (let i = 0; i < components.length; i += 100) {
    const keys = components.slice(i, i + 100).map((c) => c.key).join(',');
    const res = await sonarApi(`/api/measures/search?projectKeys=${encodeURIComponent(keys)}&metricKeys=${METRICS}`);
    for (const m of res.measures) (measures[m.component] = measures[m.component] || {})[m.metric] = m.value;
  }
  return components.map((c) => ({ key: c.key, name: c.name, analysisDate: c.analysisDate || null, measures: measures[c.key] || {} }));
}
async function listProjects() {
  const runs = withProjects(loadRuns());
  let sonar = [];
  let sonarError = null;
  try { sonar = await sonarProjects(); } catch (e) { sonarError = e.message; }
  const byId = new Map(sonar.map((p) => [p.key, { id: p.key, ...p, path: null, lastRun: null, running: false }]));
  for (const r of runs) {
    let p = byId.get(r.project);
    if (!p) {
      const isPath = r.project.startsWith('path:');
      p = { id: r.project, key: isPath ? null : r.project, name: path.posix.basename(r.path), analysisDate: null, measures: {}, path: null, lastRun: null, running: false };
      byId.set(r.project, p);
    }
    if (!p.lastRun) { p.lastRun = r; p.path = r.path; }
    if (r.status === 'running') p.running = true;
  }
  const time = (p) => Math.max(Date.parse(p.analysisDate || 0) || 0, Date.parse((p.lastRun && p.lastRun.started) || 0) || 0);
  return { sonarError, projects: [...byId.values()].sort((a, b) => time(b) - time(a)) };
}

// ---------- API ----------
const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

app.get('/api/info', wrap(async (req, res) => {
  let sonar = 'DOWN';
  try { sonar = (await (await fetch(SONAR_URL + '/api/system/status')).json()).status; } catch { /* не запущен */ }
  res.json({ sonar, token: fs.existsSync(TOKEN_FILE), sonarUrl: SONAR_PUBLIC_URL, running: [...active.keys()], settings: loadSettings() });
}));

app.get('/api/settings', (req, res) => res.json(loadSettings()));
app.put('/api/settings', (req, res) => {
  const n = Number(req.body && req.body.maxParallel);
  if (!Number.isInteger(n) || n < 1 || n > 9) return res.status(400).json({ error: 'Одновременно анализов: от 1 до 9' });
  const settings = { ...loadSettings(), maxParallel: n };
  fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 1));
  res.json(settings);
});

app.get('/api/dirs', wrap(async (req, res) => {
  const dir = safePath(req.query.path);
  let entries;
  try { entries = await fs.promises.readdir(dir, { withFileTypes: true }); } catch (e) { throw httpError(400, `Папка недоступна: ${dir} (${e.code})`); }
  let names = entries.filter((e) => e.isDirectory() && !/^[.$]/.test(e.name) && !SKIP.has(e.name)).map((e) => e.name);
  // В корне Docker Desktop показывает диски дважды (c и C) и служебные папки - оставляем буквы дисков
  if (dir === ROOT) names = [...new Set(names.filter((n) => /^[a-z]$/i.test(n)).map((n) => n.toLowerCase()))];
  names.sort((a, b) => a.localeCompare(b, 'ru', { sensitivity: 'base' }));
  const total = names.length;
  names = names.slice(0, LIST_MAX);
  const detect = dir !== ROOT && total <= DETECT_MAX;
  const tools = detect ? await mapLimited(names.map((n) => path.posix.join(dir, n)), 16, toolOf) : [];
  const dirs = names.map((name, k) => ({ name, path: path.posix.join(dir, name), tool: tools[k] || null }));
  res.json({ path: dir, tool: dir === ROOT ? null : await toolOf(dir), total, detected: detect, dirs });
}));

app.get('/api/projects', wrap(async (req, res) => res.json(await listProjects())));

// История анализов проекта в SonarQube (в том числе запущенных не со страницы)
app.get('/api/projects/analyses', wrap(async (req, res) => {
  const { analyses } = await sonarApi(`/api/project_analyses/search?ps=30&project=${encodeURIComponent(String(req.query.key || ''))}`);
  res.json(analyses);
}));

// Убрать запуски папки со страницы (в SonarQube проект остаётся)
app.delete('/api/projects', (req, res) => {
  const dir = safePath(req.query.path);
  if ([...active.values()].some((a) => a.run.path === dir)) return res.status(409).json({ error: 'По этой папке идёт анализ' });
  for (const run of loadRuns()) if (run.path === dir) removeRun(run.id);
  res.json({ ok: true });
});

app.get('/api/runs', (req, res) => res.json(withProjects(loadRuns())));

app.post('/api/runs', wrap(async (req, res) => res.status(201).json(startRun(req.body || {}))));

app.post('/api/runs/:id/stop', (req, res) => {
  const entry = active.get(req.params.id);
  if (!entry) return res.status(404).json({ error: 'Этот анализ не идёт' });
  entry.run.stopped = true;
  entry.proc.kill('SIGTERM'); // analyze.sh останавливает и контейнер сборки
  res.json({ ok: true });
});

// Лог: уже записанное + поток новых строк, пока анализ идёт (Server-Sent Events)
app.get('/api/runs/:id/log', (req, res) => {
  const file = runFile(path.basename(req.params.id), 'log');
  res.set({ 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', Connection: 'keep-alive' });
  res.flushHeaders();
  send(res, 'log', fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '');
  const entry = active.get(req.params.id);
  if (entry) {
    entry.clients.add(res);
    req.on('close', () => entry.clients.delete(res));
  } else {
    const run = loadRuns().find((r) => r.id === req.params.id);
    send(res, 'end', run || null);
    res.end();
  }
});

app.use((err, req, res, next) => { // eslint-disable-line no-unused-vars
  if (!err.status) console.error(err);
  res.status(err.status || 500).json({ error: err.message });
});

app.listen(PORT, () => console.log(`SonarQube UI: http://0.0.0.0:${PORT}, SonarQube ${SONAR_URL}`));
