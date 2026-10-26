# Локальные сервисы в Docker

Пять S3-совместимых хранилищ плюс Kafka, Elasticsearch, ActiveMQ, PostgreSQL, Spark, мониторинг Spring-приложений (Prometheus + Grafana) и конвертер документов с веб-интерфейсами. Всё описано в одном [docker-compose.yml](docker-compose.yml) (проект `devstack`). Порты не пересекаются, поэтому можно запускать всё сразу. Данные лежат в `<папка>/data` (у zenko ещё `metadata`) и сохраняются после пересоздания контейнеров. Исключение — PostgreSQL, pgAdmin, Prometheus и Grafana: их данные в именованных томах Docker (см. [postgres/README.md](postgres/README.md#где-хранятся-данные)).

## Ссылки, порты, ключи

### S3-хранилища

| Сервис | Папка | Веб-интерфейс | S3 API (endpoint) | Access key / Secret key |
|---|---|---|---|---|
| minio | [minio](minio/README.md) | http://localhost:9001 | http://localhost:9000 | `admin` / `admin123` |
| rustfs | [rustfs](rustfs/README.md) | http://localhost:9003 | http://localhost:9002 | `admin` / `admin123` |
| zenko | [zenko_cloudserver](zenko_cloudserver/README.md) | http://localhost:9006/zenko/buckets | http://localhost:9004 | `admin` / `admin123` |
| s3proxy | [s3proxy](s3proxy/README.md) | http://localhost:9006/s3proxy/buckets | http://localhost:9005 | `admin` / `admin123` |
| seaweedfs | [seaweedfs](seaweedfs/README.md) | http://localhost:8888 (Filer), http://localhost:9333 (Master) | http://localhost:8333 | `admin` / `admin123` |

Ключи у всех одинаковые: **`admin` / `admin123`**, регион `us-east-1`. Пароль не короче 8 символов — этого требует MinIO, поэтому не `admin/admin`.

После смены ключей старые профили и настройки клиентов перестанут подходить: заново запустите `aws-profiles.bat`, а для `mc` в minio заново выполните `mc alias set` (см. [minio/README.md](minio/README.md)). Бакеты и файлы от смены ключей не зависят.

### S3 Manager

Общий веб-интерфейс для **всех пяти** хранилищ: http://localhost:9006. Страница хранилища — `http://localhost:9006/<хранилище>/buckets` (`minio`, `rustfs`, `zenko`, `s3proxy`, `seaweedfs`). Умеет: бакеты (создать, удалить), загрузку файлов и папок, скачивание (в том числе ZIP), удаление, временные ссылки, метаданные. Логина нет.

Для zenko и s3proxy это единственный UI, у остальных он дополняет родной. Поднимается вместе с любым хранилищем (`<папка>\start.bat`, `start-s3.bat`, `start-all.bat`). Если какое-то хранилище выключено, на его странице будет ошибка подключения — остальные работают.

### Сервисы

| Сервис | Папка | Веб-интерфейс | Подключение для приложений | Вход |
|---|---|---|---|---|
| Kafka + Kafka UI | [kafka](kafka/README.md) | http://localhost:8080 | `localhost:9092` | без логина |
| Elasticsearch + Kibana | [elasticsearch](elasticsearch/README.md) | http://localhost:5601 | http://localhost:9200 | без логина |
| ActiveMQ Classic | [activemq](activemq/README.md) | http://localhost:8161/admin | `tcp://localhost:61616` (AMQP 5672, STOMP 61613, MQTT 1883, WS 61614) | консоль `admin` / `admin123`, клиенты без логина |
| PostgreSQL 16 + pgAdmin | [postgres](postgres/README.md) | http://localhost:5050 | `localhost:5434` (`jdbc:postgresql://localhost:5434/postgres`) | БД `postgres` / `admin123`, pgAdmin без логина |
| Spark 3.5.2 (Spark Connect) + File Browser | [spark](spark/README.md) | http://localhost:4040 (Spark UI), http://localhost:8090 (файлы) | `sc://localhost:15002`, файлы — `/data` (папка `spark\data`) | без логина |
| Мониторинг: Prometheus + Grafana | [monitoring](monitoring/README.md) | http://localhost:3000 (Grafana), http://localhost:9090 (Prometheus) | сам читает `/actuator/prometheus` Spring-приложений на порту **8199** (другие порты — в `monitoring\prometheus\targets.yml`) | без логина |
| Конвертер документов (LibreOffice + JODConverter) | [converter](converter/README.md) | http://localhost:8095/swagger-ui.html (Swagger UI) | `POST http://localhost:8095/lool/convert-to` (API LibreOffice Online: поля `data` и `format`) | без логина |

Spark работает без Hadoop-кластера (HDFS/YARN не нужны): файлы лежат в папке `spark\data`, работать с ними удобно через File Browser — подробнее в [spark/README.md](spark/README.md).

PostgreSQL доступен на порту **5434**.

## Запуск

Двойной клик:

| Файл | Что делает |
|---|---|
| `start-all.bat` | запускает **всё** и печатает ссылки |
| `stop-all.bat` | останавливает всё |
| `start-s3.bat` / `stop-s3.bat` | только S3-хранилища |
| `start-services.bat` / `stop-services.bat` | только Kafka, Elasticsearch, ActiveMQ, PostgreSQL, Spark, мониторинг, конвертер (вместе с UI) |
| `status.bat` | статус контейнеров + ссылки |
| `menu.bat` | меню: всё / группа / один сервис (старт, стоп, рестарт, логи), открыть UI в браузере |
| `aws-profiles.bat` | один раз создаёт профили AWS CLI под каждое хранилище |
| `postgres\backup.bat` | бэкап всех баз PostgreSQL в `postgres\backup\` |
| `<папка>\start.bat`, `stop.bat`, `logs.bat` | то же для одного сервиса (`logs.bat` — логи в реальном времени, выход Ctrl+C). У kafka и elasticsearch `start`/`stop` сразу работают и с UI. |

Нужен запущенный Docker Desktop. Автозапуска нет: после перезагрузки ПК контейнеры запускаются только bat-файлом.

Составы групп задаются в `_groups.bat`, ссылки для вывода в консоль — в `_links.bat`. Это служебные файлы, запускать их не нужно.

**Память.** Всё вместе занимает около 7 ГБ RAM: Spark ~2.5 ГБ, Elasticsearch ~1.5 ГБ, Kibana ~1 ГБ, Kafka ~0.7 ГБ, PostgreSQL + pgAdmin ~0.4 ГБ, Prometheus + Grafana ~0.3 ГБ, конвертер ~0.5 ГБ, остальное меньше. Если Docker Desktop выделено мало памяти, запускайте группами или поднимите лимит: Settings → Resources (или `.wslconfig` при WSL2-бэкенде).

То же из консоли (в этой папке):

| Команда | Что делает |
|---|---|
| `docker compose up -d` | запустить всё |
| `docker compose up -d minio rustfs` | запустить выборочно |
| `docker compose stop` | остановить всё |
| `docker compose ps -a` | статус |
| `docker compose logs -f minio` | логи |
| `docker compose pull` | обновить образы (затем `up -d`) |
| `docker compose down` | удалить контейнеры (данные в папках `data` остаются) |

## Первый запуск

**PostgreSQL** при первом запуске 10–20 секунд создаёт базу. Его данные хранятся в именованном томе Docker `devstack_postgres-data`, а не в папке, поэтому **не используйте `docker compose down -v`**: флаг `-v` удаляет тома вместе с базами. Перед экспериментами делайте `postgres\backup.bat`.

**После клонирования из git** папок `data` (и `zenko_cloudserver/metadata`) нет: они в `.gitignore`. Docker compose создаст их пустыми при первом запуске, хранилища начнут без бакетов.

**Если раньше запускали через compose, когда в нём были только S3-хранилища**, проект тогда назывался `s3-storages`. Его контейнеры займут те же имена, поэтому один раз удалите их (данные в папках `data` не пострадают):

```bat
docker compose -p s3-storages down
```

**Если запускали через `docker run`**, старые контейнеры занимают те же порты. Удалите их один раз (данные в папках `data` не пострадают):

```bat
docker rm -f minio1 s3proxy weed-mini cloudserver
docker ps -a --filter ancestor=rustfs/rustfs
docker rm -f <ID из предыдущей команды>
```

Изменения относительно старых txt:
- имена контейнеров теперь совпадают с сервисами: `minio`, `rustfs`, `zenko`, `s3proxy`, `seaweedfs`;
- у s3proxy порт **9005** (в старой инструкции по ошибке был указан 9004 — это порт zenko).

## Работа с бакетами через AWS CLI

Один раз запустить `aws-profiles.bat` (нужен AWS CLI v2.13+). Он создаёт профили `minio`, `rustfs`, `zenko`, `s3proxy`, `seaweedfs` с нужными ключами и endpoint, default-профиль не трогает. Дальше в командах достаточно `--profile <сервис>`:

| Команда | Что делает |
|---|---|
| `aws --profile minio s3 ls` | список бакетов |
| `aws --profile minio s3 mb s3://my-bucket` | создать бакет |
| `aws --profile minio s3 ls s3://my-bucket/` | содержимое бакета |
| `aws --profile minio s3 ls s3://my-bucket/ --recursive --human-readable --summarize` | всё содержимое + общий размер |
| `aws --profile minio s3 cp C:\temp\file.txt s3://my-bucket/` | загрузить файл |
| `aws --profile minio s3 cp s3://my-bucket/file.txt C:\temp\` | скачать файл |
| `aws --profile minio s3 sync C:\temp\folder s3://my-bucket/folder/` | залить папку |
| `aws --profile minio s3 rm s3://my-bucket/file.txt` | удалить объект |
| `aws --profile minio s3 rm s3://my-bucket/ --recursive` | очистить бакет |
| `aws --profile minio s3 rb s3://my-bucket --force` | удалить бакет вместе с содержимым |
| `aws --profile minio s3 presign s3://my-bucket/file.txt --expires-in 3600` | временная ссылка на файл (1 час) |
| `aws --profile minio s3api head-bucket --bucket my-bucket` | проверить, что бакет есть |

Вместо `minio` подставьте `rustfs`, `zenko`, `s3proxy` или `seaweedfs`.

Если AWS CLI старее 2.13 (не понимает `endpoint_url` в профиле) — добавляйте endpoint явно: `aws --profile minio --endpoint-url http://localhost:9000 s3 ls`.

Специфичные для каждого хранилища команды — в README внутри папок.

## Если что-то не запускается

- `docker compose logs <сервис>` или `<папка>\logs.bat` — причина почти всегда видна в логах.
- Kibana пишет «server is not ready yet» — подождите 1–2 минуты, она ждёт Elasticsearch.
- Elasticsearch или Kafka падают с кодом 137 — не хватает памяти Docker Desktop (см. «Память» выше).
- Порт занят: `netstat -ano | findstr :9000` → найти PID и процесс в диспетчере задач (часто это старый контейнер из `docker run`, см. выше).
- Проверить, что compose-файл корректен: `docker compose config`.
