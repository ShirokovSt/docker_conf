# TeamCity 2026.1.1

Локальный CI-сервер: агенты Linux с JDK 8/11/17/21, Maven и Docker, сборки из git (Bitbucket и др.), из локального репозитория или папки, Remote Run из IDEA.

| | |
|---|---|
| Веб-интерфейс | http://localhost:8111 |
| Логин | `admin` / `admin123` — создаётся сам при первом запуске |
| Контейнеры | `teamcity` (сервер), `teamcity-db` (его PostgreSQL), `teamcity-agent-1` (+ `teamcity-agent-2`, `-3` по желанию) |
| Агенты | `Agent (devstack)-N`: JDK 8 / 11 / 17 / 21, Maven 3.6.3 / 3.9.16, Gradle (wrapper), git, Docker + compose |
| База | в pgAdmin http://localhost:5050, сервер `teamcity-db (TeamCity)` ([postgres](../postgres/README.md)) |
| Метрики | Grafana http://localhost:3000/d/teamcity — агенты, очередь, сборки, память сервера ([monitoring](../monitoring/README.md#teamcity)) |
| Лицензия | бесплатная Professional: до 3 агентов и 100 конфигураций сборок |
| Описание | [docker-compose.yml](docker-compose.yml), подключён к общему [../docker-compose.yml](../docker-compose.yml) через `include` |

Запуск: `start.bat`, остановка: `stop.bat`, лог сервера: `logs.bat`. Из корня `docker_conf`: `start-cicd.bat` / `stop-cicd.bat`, вместе со всем — `start-all.bat` / `stop-all.bat`. В `menu.bat` — пункты 8, 9 и 10 «Агенты CI/CD» (статус, агенты, хранение логов, база, метрики).

## Первый запуск

1. `start.bat`, через 1–2 минуты открыть http://localhost:8111.
2. **Proceed**, затем **принять лицензионное соглашение** JetBrains — единственный ручной шаг. Если мастер спросит базу: PostgreSQL, хост `teamcity-db`, база `teamcity`, `teamcity` / `admin123`.
3. Остальное делает [server-init.sh](server-init.sh) при каждом запуске сервера:
   - JDBC-драйвер PostgreSQL качается с Maven Central (кнопка мастера качает с download.jetbrains.com, а он из РФ отвечает 451);
   - если пользователей нет — создаётся администратор `admin` / `admin123` (`TEAMCITY_ADMIN_USER` / `TEAMCITY_ADMIN_PASSWORD` в [docker-compose.yml](docker-compose.yml), потом пароль меняется в UI). Если мастер предложит создать администратора — обновите страницу и войдите под `admin`;
   - максимальный размер артефакта — 1024 МБ вместо 300 МБ у TeamCity по умолчанию: `TEAMCITY_MAX_ARTIFACT_MB` в [docker-compose.yml](docker-compose.yml) или `.env`, менять там, а не в Global Settings;
   - если правила хранения логов нет — ставится «3 последних билда» (см. «Хранение логов билдов»).
4. **Agents → Unauthorized → Authorize** для `Agent (devstack)-1`. Один раз: авторизация хранится в томе агента.

## Где что хранится

| Что | Где |
|---|---|
| Сборки, история, пользователи | база `teamcity` в `teamcity-db`, том `devstack_teamcity-db-data` |
| Настройки проектов, артефакты, логи сборок, JDBC-драйвер | data directory, том `devstack_teamcity-data` (`/data/teamcity_server/datadir`) |
| Логи сервера | папка `teamcity\logs` |
| Авторизация, checkout, кеши Gradle / Maven агента | тома `devstack_teamcity-agent-N-conf`, `-work`, `-home` |
| Плагины, инструменты, служебные данные, temp и логи агента | тома `devstack_teamcity-agent-N-plugins`, `-tools`, `-system`, `-temp`, `-logs` |

Тома переживают пересоздание контейнеров и обновление образов, **удаляются только `docker compose down -v`** или `docker volume rm`. Все папки, которые образ агента объявляет томами, подключены к именованным томам, а `/var/lib/docker` — к `tmpfs`, поэтому анонимных томов у агентов нет и после удаления контейнера ничьих томов не остаётся. Анонимные тома агентов, созданных до этого, при первом запуске становятся ничьими (~0,5 ГБ на агента; плагины агент заново скачает с сервера за 1–2 минуты) — удалить их: `docker volume prune`. Бэкап: **Administration → Backup → Start Backup**, затем `docker cp teamcity:/data/teamcity_server/datadir/backup teamcity\backup`; только база — `docker exec teamcity-db pg_dump -U teamcity -Fc teamcity > teamcity\teamcity.dump`.

## Папки этого ПК в сборках (`/host`)

Сервер и агенты видят **диск C** как `/host/c`, только на чтение: `C:\work\app` = `/host/c/work/app`. Другое задаётся в `docker_conf\.env` (пример — [../.env.example](../.env.example)), после правки — `stop.bat` + `start.bat`:

| `TEAMCITY_HOST_DIR` | Что видно сборкам |
|---|---|
| не задан | диск C |
| `d/work` | только `D:\work` (как `/host/d/work`) — так безопаснее: сборкам не виден остальной компьютер |
| пусто (`TEAMCITY_HOST_DIR=`) | все диски ПК |

Пути внутри от значения не зависят, поэтому настройки сборок менять не нужно. Учтите: на диске C лежат и профили пользователей (`C:\Users\...` с SSH-ключами и токенами), а читать `/host` может любой шаг сборки.

## Агенты

Образ — официальный `jetbrains/teamcity-agent:2026.1.1` плюс JDK, Maven, `rsync` и `devstack-sync` ([agent/Dockerfile](agent/Dockerfile)). Переменные — как у типового Linux-агента TeamCity, поэтому готовые настройки сборок работают без правок:

| Что | Параметр для сборки |
|---|---|
| JDK 1.8 / 11 / 17 | `%env.JDK_1_8_x64%`, `%env.JDK_11_0_x64%`, `%env.JDK_17_0_x64%` (`/opt/jdk/8`, `11`, `17`) |
| JDK 21 (`JAVA_HOME`) | `%env.JDK_21_0_x64%` |
| Maven 3.6.3 / 3.9.16 | `%teamcity.tool.maven.3.6.3%` / `%teamcity.tool.maven3_9%`, в командной строке `mvn` — 3.9 |
| Docker, docker compose | шаги Command Line, Testcontainers (`TESTCONTAINERS_HOST_OVERRIDE=host.docker.internal` уже задан) |

**Docker в сборках — это Docker Desktop этого ПК**: сокет `docker.sock` и группа root (`group_add: "0"`) дают любой сборке права root в Docker Desktop. Для CI со сборками в Docker и Testcontainers это обычно, но запускайте только код, которому доверяете. Пути `docker run -v` из сборки считаются на стороне Docker Desktop, поэтому рабочую папку сборки так не смонтировать — используйте `docker cp` или тома.

**Часовой пояс агентов — как у ПК**: bat-файлы запуска определяют его через `_tz.bat` и передают агентам как `TZ`. При ручном `docker compose` — `HOST_TZ` из `.env` или UTC.

**Добавить агента** — `menu.bat` → 10 «Агенты CI/CD» → 6: создаёт `teamcity-agent-2` или `-3` и запускает его; затем один раз **Agents → Unauthorized → Authorize**. Там же — запуск, остановка, логи и удаление агентов. Добавленных агентов `start-all`, `start-cicd` и `teamcity\start.bat` поднимают сами. Без меню: `docker compose up -d teamcity-agent-2` / `docker compose rm -sf teamcity-agent-2`. Из UI TeamCity агент-контейнер создать нельзя.

**Новый образ агента** — существующие теги не меняются: правка [agent/Dockerfile](agent/Dockerfile) (или сертификатов в [agent/certs](agent/certs/README.md)) → `build-image.bat 2026.1.1-4` → в `.env` `TEAMCITY_AGENT_IMAGE=devstack/teamcity-agent:2026.1.1-4` → `stop.bat` + `start.bat`. Откат — прежний тег. Если образа с нужным тегом нет (после клонирования), `start.bat` один раз соберёт его сам. Текущий по умолчанию — `2026.1.1-3`.

## Сборки

Откуда сборка берёт код, задаёт **VCS root** конфигурации:

| Источник кода | VCS root | Что собирается |
|---|---|---|
| Git-сервер по SSH | `ssh://git@<сервер>:<порт>/<проект>/<репо>.git`, **Uploaded Key** | закоммиченное и запушенное |
| Git по HTTPS | `https://...`, логин и токен | закоммиченное и запушенное |
| Локальный git-репозиторий | `file:///host/c/work/app` (буква диска маленькая), **Anonymous** | закоммиченное, пуш не нужен |
| Локальная папка как есть | без VCS root, первый шаг — рецепт «Локальная папка» | всё, включая незакоммиченное |

### Git (Bitbucket) по SSH

1. Ключ: `ssh-keygen -t ed25519 -f %USERPROFILE%\.ssh\teamcity_bitbucket -C teamcity-local`; публичный — в Bitbucket (**Manage account → SSH keys**), приватный — в TeamCity (**Root project → SSH Keys → Upload SSH Key**, виден всем проектам).
2. **Create project → Manually**, в нём **Create build configuration**, **VCS settings → Create VCS root**: Git, Fetch URL `ssh://...`, Default branch `refs/heads/master`, Branch specification `+:refs/heads/*`, Authentication **Uploaded Key** → **Test connection**.
3. **Build Steps**: Gradle (`clean build`, Gradle Wrapper, JDK `%env.JDK_17_0_x64%`), Maven (`clean install`) или Command Line. По желанию **Triggers** → VCS Trigger.
4. **Run**; другая ветка или параметры — кнопка **...** рядом с Run.

Другие способы: личный **HTTP access token** Bitbucket (права Read на проекты и репозитории) — **Create project → From a repository URL** с адресом `https://<сервер>/scm/<проект>/<репо>.git`, логином и токеном. **OAuth-подключение** (Root project → Connections → Bitbucket Server) даёт выбор репозитория из списка, но нужен Application Link от администратора Bitbucket с Redirect URL `http://localhost:8111/oauth/bitbucketserver/accessToken.html`.

### Локальная папка (незакоммиченный код)

Рецепт **«Локальная папка»** вызывает на агенте `devstack-sync`: папка ПК синхронизируется в рабочую папку сборки через `rsync`. Первая сборка переносит всё, следующие — только изменения; результаты сборки на агенте сохраняются, Gradle собирает инкрементально, поэтому **без `clean`** (`build -x test`). Не переносятся `.git`, `.gradle`, `.idea`, `node_modules`, вывод Gradle и Maven (`build`, `target`). `gradlew` с CRLF приводится к LF.

1. **Create project → Proceed without repository**, конфигурация — тоже без репозитория.
2. **Add build step** → **Your recipes** → **Локальная папка** → путь Windows, например `C:\work\my-service`.
3. Шаг Gradle `build -x test` или Maven `install`, **Run**. В логе — `devstack-sync: <папка> -> ...`.

Рецепт хранится в TeamCity; на новой установке: **Root project → Recipes → Upload private recipe** → [recipes/local-folder.yml](recipes/local-folder.yml). Без рецепта — шаг Command Line `devstack-sync "C:\work\my-service"`. Папка должна быть внутри `/host` (см. выше).

## Хранение логов билдов

Лог сборки большого проекта с тестами бывает **около 220 МБ**, поэтому **логи и артефакты хранятся только у N последних билдов каждой конфигурации — любого статуса**, у остальных удаляются; история, тесты и вкладка Changes остаются у всех. N = 3 ставит `server-init.sh` при первом запуске.

Очистка запускается сама **после каждого завершённого билда** (за билдами раз в минуту следит `server-init.sh`) и каждую ночь в 3:00, поэтому логов у конфигурации не больше N. Изменить N — `menu.bat` → 10 «Агенты CI/CD» → 13.

```bat
teamcity\log-retention.bat        :: показать N
teamcity\log-retention.bat 5      :: хранить 5 последних (до минуты)
teamcity\log-retention.bat now    :: очистить сейчас
```

То же — `menu.bat` → 10 → 13 и 14. В TeamCity это видно в Root project → **Clean-up Rules**: базовое правило «логи и артефакты всех билдов — на очистку» плюс keep rule «N последних билдов — всё». Базовые правила TeamCity сами по себе считают только успешные билды, поэтому «N любых» собрано так. Keep rule [log-retention.sh](log-retention.sh) задаёт через REST API, базовое правило (0 дней — в UI так не задать) — правкой `project-config.xml` корневого проекта с копией `project-config.xml.bak` и проверкой; сервер перечитывает файл сам за 15–60 секунд. После обновления TeamCity проверьте, что `log-retention.bat` показывает заданное число.

## Remote Run из IDEA

Remote Run собирает незакоммиченные изменения как **персональную сборку** (видна только вам, не влияет на историю).

1. Плагин **TeamCity** из Marketplace или с сервера: http://localhost:8111/update/TeamCity-IDEAplugin.zip → *Install Plugin from Disk*.
2. **TeamCity → Log In**: `http://localhost:8111`, `admin` / `admin123` (или своя учётка — тогда сборки записываются на вас).
3. Нужна конфигурация со сборкой из git, у которой **URL VCS root совпадает с `origin` до символа** (`.../repo` и `.../repo.git` для IDEA разные) — для каждого репозитория с изменениями.
4. Окно Commit → **Remote Run** (или **Git → TeamCity → Remote Run Outgoing Changes**), по желанию **Pre-tested commit**.

Без IDE: `curl -u admin:admin123 -X POST -H "Content-Type: application/xml" -d "<build personal=\"true\"><buildType id=\"ID\"/></build>" http://localhost:8111/app/rest/buildQueue`.

## Если что-то не так

- **Агент не появляется / Disconnected** — `docker logs teamcity-agent-1`; сервер должен быть запущен. Новый агент в Unauthorized — так и должно быть.
- **Сборки идут медленно, агенты падают** — не хватает памяти Docker Desktop: лимит WSL2 по умолчанию — половина RAM, поднимается в `%UserProfile%\.wslconfig` (`[wsl2]` → `memory=24GB`, затем `wsl --shutdown`). У каждого агента свой кеш Gradle — первая сборка на новом агенте всегда долгая.
- **Сборка не достаёт до сервера** (`Connection timed out`) — пересечение подсетей, см. «Сеть» в [../README.md](../README.md); частая причина — сети, оставленные Testcontainers: `docker network prune`.
- **Ошибки 451 от download.jetbrains.com** в логе — обновления плагинов из РФ не скачиваются, на сборки не влияет.
- **`Artifact file ... exceeds maximum allowed size`** — артефакт больше `TEAMCITY_MAX_ARTIFACT_MB` (по умолчанию 1024 МБ): увеличить в `.env`, затем `stop.bat` + `start.bat`.
- **`Failed to retrieve uploaded ssh key`** — ключа нет в проекте или родительских (Root project → SSH Keys).
- **Начать с нуля** — `docker compose rm -sfv teamcity teamcity-db teamcity-agent-1` (том, к которому подключён хотя бы остановленный контейнер, не удаляется), затем `docker volume rm devstack_teamcity-data devstack_teamcity-db-data` и в cmd `for %v in (conf work home plugins tools system temp logs) do docker volume rm devstack_teamcity-agent-1-%v` — **удалит все настройки и историю**.
