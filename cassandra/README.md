# Cassandra + веб-интерфейс

Apache Cassandra 5 (один узел) и свой веб-интерфейс к ней: keyspace'ы, таблицы, файлы в `blob`, просмотр данных и CQL-консоль. Заранее **ничего не создаётся** — keyspace'ы и таблицы под проект создаются в интерфейсе, так же как бакеты в S3-хранилищах.

| | |
|---|---|
| Веб-интерфейс | http://localhost:8097 — без логина |
| CQL с этого ПК | `localhost:9042` |
| CQL из других контейнеров compose | `cassandra:9042` |
| Датацентр | `datacenter1` |
| Логин | не нужен |
| Контейнеры / сервисы | `cassandra`, `cassandra-ui` |
| Версия | Cassandra 5.0.9, один узел |
| Данные | именованный том Docker `devstack_cassandra-data` (не папка, см. ниже) |
| Память | ~1,2–1,5 ГБ (heap ограничен 1 ГБ) |

Запуск: `start.bat`, остановка: `stop.bat`, логи: `logs.bat`, консоль `cqlsh`: `cqlsh.bat`. Всё сразу — `start-all.bat` или `start-services.bat` в корне.

**Первый запуск — около минуты.** Cassandra стартует 30–60 секунд, интерфейс поднимается, когда она готова. При самом первом запуске ещё собирается образ интерфейса (нужен доступ к npm-реестру).

Образ интерфейса пересобирается при каждом запуске, поэтому правки в `cassandra/ui` применяются сами: `git pull` → `start.bat`. Если ничего не менялось, сборка идёт из кэша и занимает секунды; доступ к npm-реестру нужен, только если поменялся `package.json`.

## Подготовка под проект

Приложения обычно ждут, что keyspace (а часто и таблицы) уже есть: драйвер Cassandra сам их не создаёт. Поэтому перед первым запуском приложения один раз:

1. http://localhost:8097 → **+ Keyspace** → имя, например `my_app`. Создаётся с `SimpleStrategy`, replication factor 1 — узел один.
2. Таблицы:
   - **хранилище файлов** (UUID → содержимое): у keyspace кнопка **+ таблица** → имя (по умолчанию `obj`). Создаётся таблица `(id uuid PRIMARY KEY, content blob)`;
   - **любая другая таблица** — **CQL-консоль**, например:
     ```sql
     CREATE TABLE my_app.events (id uuid, created timestamp, payload text, PRIMARY KEY (id, created));
     ```
3. В приложении: хост `localhost:9042`, датацентр `datacenter1`, keyspace `my_app`.

Spring Boot (`spring-boot-starter-data-cassandra`):

```properties
spring.cassandra.contact-points=localhost:9042
spring.cassandra.local-datacenter=datacenter1
spring.cassandra.keyspace-name=my_app
```

> На одном узле используйте replication factor 1. Если keyspace создан с RF 3 (как на боевом кластере), запросы с уровнем согласованности `QUORUM`/`LOCAL_QUORUM` упадут с ошибкой о нехватке реплик.

## Веб-интерфейс

Слева — дерево keyspace → таблицы (системные keyspace скрыты). Таблицы, где ключ — `uuid` и есть колонка `blob`, помечены **файлы**.

| Что | Где |
|---|---|
| Создать / удалить keyspace | **+ Keyspace** / ✕ у keyspace (удаление — с вводом имени для подтверждения) |
| Создать таблицу для файлов | **+ таблица** у keyspace |
| **Загрузить файлы** | таблица → вкладка **Файлы** → перетащить или **выберите**; UUID создаётся сам или задаётся свой. После загрузки UUID показывается, его можно скопировать |
| Найти файл | поиск по UUID |
| Открыть / скачать | кнопки у файла. Тип определяется по содержимому (pdf, картинки, docx/xlsx/pptx, zip, txt, json, xml); PDF, картинки и текст открываются в браузере |
| Удалить файлы | ✕ у файла или отметить несколько → **Удалить отмеченные** |
| Данные любой таблицы | вкладка **Данные** (blob показывается размером) |
| Схема таблицы | вкладка **Схема** (`CREATE TABLE ...`) |
| Очистить / удалить таблицу | кнопки над вкладками |
| Любой CQL-запрос | **CQL-консоль** (Ctrl+Enter — выполнить), примеры и история запросов |

**Размер файла — до 15 МБ.** Cassandra по умолчанию не принимает одну запись больше 16 МБ (половина `commitlog_segment_size`). Так же это ограничение действует и для приложений: для больших файлов Cassandra не предназначена.

## Консоль cqlsh

`cqlsh.bat` открывает консоль внутри контейнера, выход — `exit`.

| Команда | Что делает |
|---|---|
| `DESCRIBE KEYSPACES;` | список keyspace |
| `DESCRIBE my_app;` | все таблицы keyspace с их схемой |
| `CREATE KEYSPACE my_app WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};` | создать keyspace |
| `CREATE TABLE my_app.obj (id uuid PRIMARY KEY, content blob);` | таблица для файлов |
| `SELECT id FROM my_app.obj LIMIT 20;` | первые 20 UUID |
| `SELECT count(*) FROM my_app.obj;` | количество строк (на больших таблицах медленно) |
| `DELETE FROM my_app.obj WHERE id = <uuid>;` | удалить строку |
| `TRUNCATE my_app.obj;` | очистить таблицу |
| `DROP KEYSPACE my_app;` | удалить keyspace со всеми таблицами |

Одной командой без входа в консоль: `docker exec cassandra cqlsh -e "DESCRIBE KEYSPACES;"`

## Где хранятся данные

В именованном томе Docker `devstack_cassandra-data`, а не в папке: Cassandra работает не от root, а папки с диска Windows ей не подходят. Данные переживают перезапуск и пересоздание контейнера, `docker compose down`, обновление образа. Удаляются только при `docker compose down -v` или `docker volume rm devstack_cassandra-data`.

Выгрузить таблицу в файл и загрузить обратно (папка `/tmp` внутри контейнера):

| Команда | Что делает |
|---|---|
| `docker exec cassandra cqlsh -e "COPY my_app.events TO '/tmp/events.csv' WITH HEADER = true;"` | выгрузить таблицу в CSV |
| `docker cp cassandra:/tmp/events.csv .` | забрать файл на ПК |
| `docker cp events.csv cassandra:/tmp/events.csv` | положить файл в контейнер |
| `docker exec cassandra cqlsh -e "COPY my_app.events FROM '/tmp/events.csv' WITH HEADER = true;"` | загрузить из CSV (таблица должна существовать) |
| `docker exec cassandra nodetool snapshot my_app` | снимок keyspace внутри тома (быстрый, для отката) |

## Запасной вариант: docker run

Без интерфейса, только Cassandra:

```bat
docker run -d ^
  --name cassandra ^
  -p 9042:9042 ^
  -v devstack_cassandra-data:/var/lib/cassandra ^
  -e MAX_HEAP_SIZE=1G ^
  -e HEAP_NEWSIZE=256M ^
  -e CASSANDRA_CLUSTER_NAME=devstack ^
  -e CASSANDRA_DC=datacenter1 ^
  -e CASSANDRA_ENDPOINT_SNITCH=GossipingPropertyFileSnitch ^
  cassandra:5.0.9
```
