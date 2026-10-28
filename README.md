# Локальные сервисы в Docker

Пять S3-совместимых хранилищ плюс Kafka, Elasticsearch, ActiveMQ, PostgreSQL, Spark, мониторинг Spring-приложений (Prometheus + Grafana), конвертер документов, тестовая почта (Mailpit), Cassandra, просмотр логов (Dozzle) и CI/CD (TeamCity) с веб-интерфейсами. Всё описано в одном [docker-compose.yml](docker-compose.yml) (проект `devstack`, TeamCity подключён из своей папки). Порты не пересекаются, поэтому можно запускать всё сразу. Данные лежат в `<папка>/data` (у zenko ещё `metadata`) и сохраняются после пересоздания контейнеров. Исключение — PostgreSQL, pgAdmin, Prometheus, Grafana и Cassandra: их данные в именованных томах Docker (см. [postgres/README.md](postgres/README.md#где-хранятся-данные)).

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
| Мониторинг: Prometheus + Grafana | [monitoring](monitoring/README.md) | http://localhost:3000 (Grafana), http://localhost:9090 (Prometheus) | сам читает `/actuator/prometheus` Spring-приложений на порту **8199** (другие порты — в `monitoring\prometheus\targets.yml`) и метрики TeamCity | без логина |
| Конвертер документов (LibreOffice + JODConverter) | [converter](converter/README.md) | http://localhost:8095/swagger-ui.html (Swagger UI) | `POST http://localhost:8095/lool/convert-to` (API LibreOffice Online: поля `data` и `format`) | без логина |
| Тестовая почта (Mailpit) | [mailpit](mailpit/README.md) | http://localhost:8025 | SMTP `localhost:1025` (из контейнеров — `mailpit:1025`), без TLS, логин и пароль любые | без логина |
| Cassandra 5 + веб-интерфейс | [cassandra](cassandra/README.md) | http://localhost:8097 (keyspace'ы, таблицы, файлы, CQL) | `localhost:9042`, датацентр `datacenter1`; keyspace и таблицы создаются в интерфейсе | без логина |
| Логи всех контейнеров (Dozzle) | [dozzle](dozzle/README.md) | http://localhost:8098 (только с этого ПК) | — (поиск по логам, старт / стоп / перезапуск контейнеров) | без логина |

Spark работает без Hadoop-кластера (HDFS/YARN не нужны): файлы лежат в папке `spark\data`, работать с ними удобно через File Browser — подробнее в [spark/README.md](spark/README.md).

PostgreSQL доступен на порту **5434**.

### CI/CD

| Сервис | Папка | Веб-интерфейс | Подключение | Вход |
|---|---|---|---|---|
| TeamCity 2026.1.1 + БД + агенты | [teamcity](teamcity/README.md) | http://localhost:8111 | Remote Run из IDEA — плагин TeamCity, сервер `http://localhost:8111` | `admin` / `admin123` |

Агенты с JDK 8/11/17/21, Maven и Docker; сборки из git (Bitbucket и др.), локального git-репозитория или папки на диске C (другие папки — `TEAMCITY_HOST_DIR` в `.env`). По умолчанию работает один агент, ещё два добавляются в `menu.bat` → 10 «Агенты CI/CD». Логи и артефакты хранятся у 3 последних билдов каждой конфигурации, очистка — после каждого билда (число меняется там же или `teamcity\log-retention.bat`). Отдельных контейнеров для просмотра не нужно: база TeamCity — в pgAdmin (сервер `teamcity-db`), метрики — дашборд «TeamCity» в Grafana. Подробно — [teamcity/README.md](teamcity/README.md).

## Запуск

Двойной клик:

| Файл | Что делает |
|---|---|
| `start-all.bat` | запускает **всё** и печатает ссылки |
| `stop-all.bat` | останавливает всё |
| `start-s3.bat` / `stop-s3.bat` | только S3-хранилища |
| `start-services.bat` / `stop-services.bat` | только Kafka, Elasticsearch, ActiveMQ, PostgreSQL, Spark, мониторинг, конвертер, почта, Cassandra, Dozzle (вместе с UI) |
| `start-cicd.bat` / `stop-cicd.bat` | только CI/CD: TeamCity, его БД, агенты |
| `teamcity\start.bat` / `teamcity\stop.bat` | то же, из папки `teamcity` |
| `status.bat` | статус контейнеров + ссылки |
| `menu.bat` | меню: всё / группа / один сервис (старт, стоп, рестарт, логи), агенты TeamCity (добавить, запустить, удалить), открыть UI в браузере |
| `aws-profiles.bat` | один раз создаёт профили AWS CLI под каждое хранилище |
| `postgres\backup.bat` | бэкап всех баз PostgreSQL в `postgres\backup\` |
| `<папка>\start.bat`, `stop.bat`, `logs.bat` | то же для одного сервиса (`logs.bat` — логи в реальном времени, выход Ctrl+C). У kafka и elasticsearch `start`/`stop` сразу работают и с UI. |

Нужен запущенный Docker Desktop. Автозапуска нет: после перезагрузки ПК контейнеры запускаются только bat-файлом.

Составы групп задаются в `_groups.bat`, ссылки для вывода в консоль — в `_links.bat`, часовой пояс ПК для контейнеров TeamCity определяет `teamcity\_tz.bat`, добавленных агентов TeamCity находит `teamcity\_agents.bat`, сеть Docker со свободной подсетью создаёт `_net.bat` (с `_net.ps1`). Это служебные файлы, запускать их не нужно.

**Память.** Всё вместе занимает около 11,5 ГБ RAM: Spark ~2.5 ГБ, Elasticsearch ~1.5 ГБ, Kibana ~1 ГБ, Kafka ~0.7 ГБ, PostgreSQL + pgAdmin ~0.4 ГБ, Prometheus + Grafana ~0.3 ГБ, конвертер ~0.5 ГБ, почта ~30 МБ, Cassandra ~1.5 ГБ, Dozzle ~30 МБ, TeamCity ~2.5 ГБ (сервер ~1.8 ГБ, агент ~0.7 ГБ в простое, каждый следующий агент — ещё столько же и больше во время сборки), остальное меньше. Без TeamCity — около 8,5 ГБ: `start-s3.bat` + `start-services.bat`. При первом запуске TeamCity образ агента собирается несколько минут. Если Docker Desktop выделено мало памяти, запускайте группами или поднимите лимит: Settings → Resources (или `.wslconfig` при WSL2-бэкенде).

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

## Сеть

Все контейнеры — в сети Docker `devstack_default`. Её подсеть подбирается автоматически: при первом запуске любой bat-файл запуска (`start-all`, `start-s3`, `start-services`, `menu`, `<папка>\start.bat`) вызывает служебный `_net.bat`, тот выбирает подсеть `/24`, которая **не пересекается ни с маршрутами этого ПК** (VPN, WSL и другие подключённые сети), **ни с другими сетями Docker**, и создаёт сеть. Дальше сеть просто переиспользуется — подсеть больше не меняется, а compose подключается к готовой сети (`external`). На другом ПК подсеть подберётся под его сети.

Зачем: сам Docker берёт подсети из `172.17–172.31`, а в тех же диапазонах бывают сети, к которым подключён ПК (VPN, локальная сеть). Если подсеть сети Docker с такой сетью совпадает, контейнеры (в том числе сборки TeamCity) до её серверов не достают. От подсети ничего не зависит в настройках сервисов: друг к другу они обращаются по именам, снаружи — через `localhost`.

- Первый запуск лучше делать при подключённом VPN — тогда при подборе учитываются и его сети.
- Подобрать подсеть заново (например, подключилась новая сеть или VPN): `stop-all.bat`, затем `docker compose down` и `docker network rm devstack_default`, затем `start-all.bat`. Контейнеры пересоздаются, данные в папках `data` и томах остаются.
- `docker compose up` вручную, без bat-файлов, работает, если сеть уже создана; на чистом ПК — сначала `start-all.bat` (или `_net.bat`).

Проверить в PowerShell, какие подсети заняты сетями Docker:

```powershell
docker network ls -q | ForEach-Object { docker network inspect $_ --format "{{.Name}} {{range .IPAM.Config}}{{.Subnet}}{{end}}" }
```

Сеть Docker, которая пересекается с чужой подсетью, отрезает её от **всех** контейнеров ПК, даже из других сетей. Частая причина — пустые сети, которые оставляют тесты на Testcontainers; удаляются `docker network prune`.

Файл `.env` рядом с `docker-compose.yml` не обязателен: у всех переменных есть значения по умолчанию. Он нужен, только чтобы что-то переопределить на этом ПК: скопируйте нужные строки из [.env.example](.env.example) (там все переменные с пояснениями). Переменные TeamCity — в [teamcity/README.md](teamcity/README.md).

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

- `docker compose logs <сервис>`, `<папка>\logs.bat` или http://localhost:8098 (Dozzle, логи всех контейнеров) — причина почти всегда видна в логах.
- Kibana пишет «server is not ready yet» — подождите 1–2 минуты, она ждёт Elasticsearch.
- Elasticsearch или Kafka падают с кодом 137 — не хватает памяти Docker Desktop (см. «Память» выше).
- Порт занят: `netstat -ano | findstr :9000` → найти PID и процесс в диспетчере задач (часто это старый контейнер из `docker run`, см. выше).
- Проверить, что compose-файл корректен: `docker compose config`.
- Из контейнера не открывается нужный сервер — возможно, пересечение подсетей, см. «Сеть».
