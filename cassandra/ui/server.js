// Веб-интерфейс Cassandra для docker_conf: keyspace'ы, таблицы, файлы (blob по uuid), просмотр данных, CQL-консоль.
// Одна страница (public/index.html) + JSON API ниже. Подключение - переменные окружения (docker-compose.yml).
'use strict';

const express = require('express');
const multer = require('multer');
const cassandra = require('cassandra-driver');

const HOST = process.env.CASSANDRA_HOST || 'cassandra';
const PORT_CQL = Number(process.env.CASSANDRA_PORT || 9042);
const DC = process.env.CASSANDRA_DC || 'datacenter1';
const PORT = Number(process.env.PORT || 8080);
// Cassandra по умолчанию не принимает запись больше половины commitlog_segment_size (32 МБ) - 16 МБ на строку
const MAX_FILE = Number(process.env.MAX_FILE_MB || 15) * 1024 * 1024;

const { Uuid } = cassandra.types;

// ---------- подключение (переподключается само, если Cassandra ещё не готова или перезапускалась) ----------
let client = null;
async function db() {
  if (client) return client;
  const c = new cassandra.Client({
    contactPoints: [HOST],
    localDataCenter: DC,
    protocolOptions: { port: PORT_CQL },
    socketOptions: { readTimeout: 60000 },
  });
  try {
    await c.connect();
  } catch (e) {
    c.shutdown().catch(() => {});
    const inner = e.innerErrors ? Object.values(e.innerErrors)[0] : null;
    const reason = (inner && (inner.code || inner.message)) || e.message;
    throw httpError(503, `Нет подключения к Cassandra ${HOST}:${PORT_CQL} (${reason}). Если она только запускается - подождите минуту и обновите страницу.`);
  }
  client = c;
  return client;
}
async function exec(query, params = [], options = {}) {
  const c = await db();
  try {
    return await c.execute(query, params, { prepare: params.length > 0, ...options });
  } catch (e) {
    if (e instanceof cassandra.errors.NoHostAvailableError) { client = null; c.shutdown().catch(() => {}); }
    throw e;
  }
}

// ---------- имена и значения ----------
const NAME_RE = /^[a-z][a-z0-9_]{0,47}$/;
function newName(raw, what) {
  const n = String(raw || '').trim().toLowerCase();
  if (!NAME_RE.test(n)) throw httpError(400, `${what}: латиница в нижнем регистре, цифры и _, начинается с буквы, до 48 символов`);
  return n;
}
// существующие имена берём из system_schema и экранируем кавычками
const q = (name) => '"' + String(name).replace(/"/g, '""') + '"';
const isSystem = (ks) => ks.startsWith('system');

function httpError(status, message) { const e = new Error(message); e.status = status; return e; }

// значение из драйвера -> JSON (blob показываем размером, а не содержимым)
function plain(v) {
  if (v === null || v === undefined) return null;
  if (Buffer.isBuffer(v)) return { blob: v.length };
  if (v instanceof Date) return v.toISOString();
  if (Array.isArray(v)) return v.map(plain);
  if (v instanceof Map) return Object.fromEntries([...v].map(([k, x]) => [String(plain(k)), plain(x)]));
  if (typeof v === 'object') {
    const t = v.constructor && v.constructor.name;
    if (t && t !== 'Object') return String(v); // Uuid, TimeUuid, Long, BigDecimal, LocalDate, InetAddress ...
    return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, plain(x)]));
  }
  return v;
}
function rowsToJson(rs) {
  const columns = (rs.columns || []).map((c) => c.name);
  return { columns, rows: (rs.rows || []).map((r) => columns.map((c) => plain(r[c]))), pageState: rs.pageState || null };
}

// ---------- схема ----------
async function columnsOf(ks, table) {
  const rs = await exec('SELECT column_name, kind, type, position FROM system_schema.columns WHERE keyspace_name = ? AND table_name = ?', [ks, table]);
  return rs.rows.map((r) => ({ name: r.column_name, kind: r.kind, type: r.type, position: r.position }));
}
// "таблица файлов": один ключ раздела типа uuid, без clustering, и колонка blob
function fileShape(cols) {
  const pk = cols.filter((c) => c.kind === 'partition_key');
  const ck = cols.filter((c) => c.kind === 'clustering');
  const blob = cols.find((c) => c.kind === 'regular' && c.type === 'blob');
  if (pk.length === 1 && pk[0].type === 'uuid' && ck.length === 0 && blob) return { key: pk[0].name, blob: blob.name };
  return null;
}
async function fileTable(ks, table) {
  const shape = fileShape(await columnsOf(ks, table));
  if (!shape) throw httpError(400, `Таблица ${ks}.${table} - не таблица файлов: нужен ключ uuid и колонка blob`);
  return shape;
}

// ---------- тип файла по первым байтам ----------
function sniff(buf) {
  const s = (n) => buf.subarray(0, n).toString('latin1');
  if (s(4) === '%PDF') return { ext: 'pdf', mime: 'application/pdf', inline: true };
  if (buf[0] === 0x89 && s(4).slice(1) === 'PNG') return { ext: 'png', mime: 'image/png', inline: true };
  if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return { ext: 'jpg', mime: 'image/jpeg', inline: true };
  if (s(4) === 'GIF8') return { ext: 'gif', mime: 'image/gif', inline: true };
  if (s(4) === 'RIFF' && buf.subarray(8, 12).toString('latin1') === 'WEBP') return { ext: 'webp', mime: 'image/webp', inline: true };
  if (s(4) === 'PK\x03\x04') {
    const head = buf.subarray(0, 64 * 1024).toString('latin1');
    if (head.includes('word/')) return { ext: 'docx', mime: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' };
    if (head.includes('xl/')) return { ext: 'xlsx', mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' };
    if (head.includes('ppt/')) return { ext: 'pptx', mime: 'application/vnd.openxmlformats-officedocument.presentationml.presentation' };
    return { ext: 'zip', mime: 'application/zip' };
  }
  if (buf[0] === 0xd0 && buf[1] === 0xcf && buf[2] === 0x11 && buf[3] === 0xe0) return { ext: 'doc', mime: 'application/msword' };
  const head = buf.subarray(0, 4096);
  if (!head.includes(0)) {
    const text = head.toString('utf8').trimStart();
    if (text.startsWith('<?xml')) return { ext: 'xml', mime: 'application/xml; charset=utf-8', inline: true };
    if (text.startsWith('{') || text.startsWith('[')) return { ext: 'json', mime: 'application/json; charset=utf-8', inline: true };
    return { ext: 'txt', mime: 'text/plain; charset=utf-8', inline: true };
  }
  return { ext: 'bin', mime: 'application/octet-stream' };
}

// ---------- API ----------
const app = express();
app.use(express.json({ limit: '1mb' }));
app.use(express.static(require('path').join(__dirname, 'public')));
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: MAX_FILE, files: 50 } });
const wrap = (fn) => (req, res, next) => fn(req, res).catch(next);

app.get('/api/info', wrap(async (req, res) => {
  const rs = await exec('SELECT release_version, data_center, cluster_name FROM system.local');
  const r = rs.first();
  res.json({ host: `${HOST}:${PORT_CQL}`, version: r.release_version, dc: r.data_center, cluster: r.cluster_name, maxFileMb: MAX_FILE / 1024 / 1024 });
}));

// дерево: keyspace'ы (без системных) -> таблицы (+ признак "таблица файлов")
app.get('/api/keyspaces', wrap(async (req, res) => {
  const kss = (await exec('SELECT keyspace_name, replication FROM system_schema.keyspaces')).rows.filter((r) => !isSystem(r.keyspace_name));
  const cols = (await exec('SELECT keyspace_name, table_name, column_name, kind, type FROM system_schema.columns')).rows;
  const tables = (await exec('SELECT keyspace_name, table_name FROM system_schema.tables')).rows;
  const result = kss.map((k) => {
    const ks = k.keyspace_name;
    const repl = k.replication || {};
    return {
      name: ks,
      replication: repl.replication_factor ? `${(repl.class || '').split('.').pop()}, RF ${repl.replication_factor}` : (repl.class || '').split('.').pop(),
      tables: tables.filter((t) => t.keyspace_name === ks).map((t) => t.table_name).sort().map((name) => {
        const shape = fileShape(cols.filter((c) => c.keyspace_name === ks && c.table_name === name).map((c) => ({ name: c.column_name, kind: c.kind, type: c.type })));
        return { name, files: shape };
      }),
    };
  }).sort((a, b) => a.name.localeCompare(b.name));
  res.json(result);
}));

app.post('/api/keyspaces', wrap(async (req, res) => {
  const name = newName(req.body.name, 'Имя keyspace');
  const rf = Math.max(1, Math.min(3, Number(req.body.rf || 1)));
  await exec(`CREATE KEYSPACE IF NOT EXISTS ${q(name)} WITH replication = {'class': 'SimpleStrategy', 'replication_factor': ${rf}}`);
  res.json({ ok: true, name });
}));

app.delete('/api/keyspaces/:ks', wrap(async (req, res) => {
  if (isSystem(req.params.ks)) throw httpError(400, 'Системные keyspace не удаляются');
  await exec(`DROP KEYSPACE IF EXISTS ${q(req.params.ks)}`);
  res.json({ ok: true });
}));

// таблица для файлов: id uuid PRIMARY KEY, content blob
app.post('/api/keyspaces/:ks/file-table', wrap(async (req, res) => {
  const name = newName(req.body.name || 'obj', 'Имя таблицы');
  await exec(`CREATE TABLE IF NOT EXISTS ${q(req.params.ks)}.${q(name)} (id uuid PRIMARY KEY, content blob)`);
  res.json({ ok: true, name });
}));

app.get('/api/tables/:ks/:t/schema', wrap(async (req, res) => {
  const rs = await exec(`DESCRIBE TABLE ${q(req.params.ks)}.${q(req.params.t)}`);
  res.json({ cql: rs.rows.map((r) => r.create_statement).join('\n'), columns: await columnsOf(req.params.ks, req.params.t) });
}));

app.get('/api/tables/:ks/:t/rows', wrap(async (req, res) => {
  const rs = await exec(`SELECT * FROM ${q(req.params.ks)}.${q(req.params.t)}`, [], {
    fetchSize: Math.min(500, Number(req.query.limit || 50)), pageState: req.query.pageState || undefined,
  });
  res.json(rowsToJson(rs));
}));

app.post('/api/tables/:ks/:t/truncate', wrap(async (req, res) => {
  if (isSystem(req.params.ks)) throw httpError(400, 'Системные таблицы не очищаются');
  await exec(`TRUNCATE ${q(req.params.ks)}.${q(req.params.t)}`);
  res.json({ ok: true });
}));

app.delete('/api/tables/:ks/:t', wrap(async (req, res) => {
  if (isSystem(req.params.ks)) throw httpError(400, 'Системные таблицы не удаляются');
  await exec(`DROP TABLE IF EXISTS ${q(req.params.ks)}.${q(req.params.t)}`);
  res.json({ ok: true });
}));

// файлы: список (uuid + размер), постранично; ?id= - поиск одного
app.get('/api/files/:ks/:t', wrap(async (req, res) => {
  const { ks, t } = req.params;
  const { key, blob } = await fileTable(ks, t);
  const from = `${q(ks)}.${q(t)}`;
  const where = req.query.id ? ` WHERE ${q(key)} = ?` : '';
  const params = req.query.id ? [parseUuid(req.query.id)] : [];
  const options = { fetchSize: Math.min(500, Number(req.query.limit || 50)), pageState: req.query.pageState || undefined, prepare: true };
  let rs; let sizes = true;
  try {
    // octet_length - функция Cassandra 5.0: размер без чтения самого blob
    rs = await exec(`SELECT ${q(key)} AS id, octet_length(${q(blob)}) AS size FROM ${from}${where}`, params, options);
  } catch (e) {
    sizes = false;
    rs = await exec(`SELECT ${q(key)} AS id FROM ${from}${where}`, params, options);
  }
  res.json({
    key, blob, sizes,
    files: rs.rows.map((r) => ({ id: String(r.id), size: sizes ? r.size : null })),
    pageState: rs.pageState || null,
  });
}));

// multer отдаёт имя файла в latin1: кириллицу перекодируем, если это действительно UTF-8
function fileName(name) {
  const utf8 = Buffer.from(name, 'latin1').toString('utf8');
  return utf8.includes('�') ? name : utf8;
}

function parseUuid(s) {
  try { return Uuid.fromString(String(s).trim()); } catch (e) { throw httpError(400, `Не UUID: ${s}`); }
}

app.post('/api/files/:ks/:t', upload.array('files'), wrap(async (req, res) => {
  const { ks, t } = req.params;
  const { key, blob } = await fileTable(ks, t);
  if (!req.files || req.files.length === 0) throw httpError(400, 'Файлы не выбраны');
  const ids = req.body.id ? [String(req.body.id)] : [];
  if (ids.length && req.files.length > 1) throw httpError(400, 'Свой UUID можно задать только для одного файла');
  const saved = [];
  for (const f of req.files) {
    const id = ids[0] ? parseUuid(ids[0]) : Uuid.random();
    await exec(`INSERT INTO ${q(ks)}.${q(t)} (${q(key)}, ${q(blob)}) VALUES (?, ?)`, [id, f.buffer]);
    saved.push({ id: String(id), name: fileName(f.originalname), size: f.size });
  }
  res.json({ ok: true, saved });
}));

app.get('/api/files/:ks/:t/:id', wrap(async (req, res) => {
  const { ks, t, id } = req.params;
  const { key, blob } = await fileTable(ks, t);
  const r = (await exec(`SELECT ${q(blob)} AS content FROM ${q(ks)}.${q(t)} WHERE ${q(key)} = ?`, [parseUuid(id)])).first();
  if (!r) throw httpError(404, `Файл ${id} не найден`);
  const buf = r.content || Buffer.alloc(0);
  const type = sniff(buf);
  const disposition = req.query.inline && type.inline ? 'inline' : 'attachment';
  res.set('Content-Type', type.mime);
  res.set('Content-Disposition', `${disposition}; filename="${id}.${type.ext}"`);
  res.set('X-File-Type', type.ext);
  res.send(buf);
}));

app.delete('/api/files/:ks/:t', wrap(async (req, res) => {
  const { ks, t } = req.params;
  const { key } = await fileTable(ks, t);
  const ids = Array.isArray(req.body.ids) ? req.body.ids : [];
  for (const id of ids) await exec(`DELETE FROM ${q(ks)}.${q(t)} WHERE ${q(key)} = ?`, [parseUuid(id)]);
  res.json({ ok: true, deleted: ids.length });
}));

// CQL-консоль: один запрос, первая страница результата
app.post('/api/cql', wrap(async (req, res) => {
  const query = String(req.body.query || '').trim().replace(/;\s*$/, '');
  if (!query) throw httpError(400, 'Пустой запрос');
  const started = Date.now();
  const rs = await exec(query, [], { prepare: false, fetchSize: 200, pageState: req.body.pageState || undefined });
  res.json({ ...rowsToJson(rs), ms: Date.now() - started });
}));

// ошибки -> JSON с понятным текстом
app.use((err, req, res, next) => { // eslint-disable-line no-unused-vars
  let status = err.status || 500;
  let message = err.message || String(err);
  if (err instanceof multer.MulterError && err.code === 'LIMIT_FILE_SIZE') {
    status = 413;
    message = `Файл больше ${MAX_FILE / 1024 / 1024} МБ: Cassandra по умолчанию не принимает строку больше 16 МБ`;
  } else if (err instanceof cassandra.errors.ResponseError) {
    status = 400;
  }
  res.status(status).json({ error: message });
});

app.listen(PORT, () => console.log(`Cassandra UI: http://0.0.0.0:${PORT}, Cassandra ${HOST}:${PORT_CQL}, dc ${DC}`));
