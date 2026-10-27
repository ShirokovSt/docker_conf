# TeamCity 2026.1.1

Локальный CI-сервер: агенты Linux с JDK 8/11/17/21, Maven и Docker, сборки из git по SSH-ключу, из локальной папки, Remote Run из IDEA.

| | |
|---|---|
| Веб-интерфейс | http://localhost:8111 |
| Логин | `admin` / `admin123` — создаётся сам при первом запуске |
| Контейнеры / сервисы | `teamcity` (сервер), `teamcity-db` (его PostgreSQL), `teamcity-agent-1` (+ `teamcity-agent-2`, `teamcity-agent-3` по желанию), `beszel` + `beszel-agent` (графики агентов), `adminer` (просмотр БД) |
| Версия | TeamCity 2026.1.1 (build 222577), PostgreSQL 16.15 |
| Агенты | `Agent (devstack)-N`: JDK 8 / 11 / 17 / 21, Maven 3.6.3 / 3.9.16, Gradle (wrapper), git, Docker + compose |
| Лицензия | бесплатная Professional: до 3 агентов и 100 конфигураций сборок |
| Описание | [docker-compose.yml](docker-compose.yml) — подключён к общему [../docker-compose.yml](../docker-compose.yml) через `include` |

Контейнеры входят в общий проект `devstack` (в Docker Desktop — в той же группе, что и остальные сервисы). Запуск: `start.bat`, остановка: `stop.bat`, логи сервера: `logs.bat`. Из корня `docker_conf`: `start-cicd.bat` / `stop-cicd.bat` — только CI/CD, `start-all.bat` / `stop-all.bat` — вместе со всем; в `menu.bat` — пункты 8 «Запустить CI/CD», 9 «Остановить CI/CD» и 10 «Агенты CI/CD».

## Первый запуск

1. `start.bat`, через 1–2 минуты открыть http://localhost:8111.
2. **Proceed**, затем **принять лицензионное соглашение** JetBrains — это единственный шаг, который делается руками.
3. Дальше всё само:
   - база — `teamcity-db`, подключение настраивается в мастере (тип PostgreSQL, хост `teamcity-db`, база `teamcity`, пользователь `teamcity` / `admin123`) — если мастер спросит;
   - JDBC-драйвер PostgreSQL сервер скачивает с Maven Central при старте (кнопка мастера качает с download.jetbrains.com, а он из РФ отвечает 451);
   - администратор `admin` / `admin123` создаётся, как только сервер запустится, если пользователей ещё нет. Если мастер предложит создать администратора — можно просто обновить страницу и войти под `admin`.
4. **Agents → Unauthorized → Authorize** для `Agent (devstack)-1`. Один раз: авторизация хранится в томе агента.

Логин и пароль администратора — `TEAMCITY_ADMIN_USER` / `TEAMCITY_ADMIN_PASSWORD` в [docker-compose.yml](docker-compose.yml). Действуют только при создании: потом пароль меняется в UI (Profile).

## Где что хранится

| Что | Где | Как посмотреть |
|---|---|---|
| Сборки, история, пользователи, права | база `teamcity` в контейнере `teamcity-db`, том `devstack_teamcity-db-data` | `docker exec -it teamcity-db psql -U teamcity` |
| Настройки проектов (XML), артефакты, логи сборок, кеши, JDBC-драйвер | data directory, том `devstack_teamcity-data` (в контейнере `/data/teamcity_server/datadir`) | Administration → Global Settings, `docker exec teamcity ls /data/teamcity_server/datadir` |
| Логи сервера | папка `teamcity\logs` | `teamcity-server.log`, `teamcity-vcs.log`, `teamcity-rest.log` |
| Логи и артефакты билдов | data directory, `system/artifacts/<проект>/<конфигурация>/<номер билда>/` (лог — в `.teamcity/logs`) | хранятся только у последних билдов, см. «Хранение логов билдов» |
| Авторизация агента | том `devstack_teamcity-agent-N-conf` | — |
| Рабочие папки сборок (checkout) | том `devstack_teamcity-agent-N-work` (`/opt/buildagent/work`) | лог сборки, строка `Checkout directory` |
| Кеши Gradle / Maven агента (`~/.gradle`, `~/.m2`) | том `devstack_teamcity-agent-N-home` | — |
| Локальные исходники для сборок | любая папка этого ПК: все диски видны в сервере и агентах как `/host` (только чтение), `D:\work\app` = `/host/d/work/app` | проводник |

Data directory и база — в именованных томах Docker, а не в папке: индексы и кеши TeamCity на диске Windows работают заметно медленнее. Тома переживают пересоздание контейнеров, `docker compose down` и обновление образов. **Удаляются только `docker compose down -v`** или `docker volume rm` — не используйте их, если данные нужны.

### Бэкап

Встроенный: **Administration → Backup → Start Backup** (настройки, база, логи сборок). Файл появится в data directory, забрать на диск:

```bat
docker cp teamcity:/data/teamcity_server/datadir/backup teamcity\backup
```

Только база: `docker exec teamcity-db pg_dump -U teamcity -Fc teamcity > teamcity\teamcity.dump`.

## Настройки — файл `.env`

Файл `.env` **не обязателен**: у всех переменных есть значения по умолчанию, а агенты добавляются в меню. Нужен, только чтобы что-то переопределить на этом ПК: `.env` в папке `docker_conf` (рядом с корневым `docker-compose.yml`), в git не попадает. После правки — `stop.bat` + `start.bat`.

| Переменная | Что задаёт | По умолчанию |
|---|---|---|
| `TEAMCITY_AGENT_IMAGE` | образ агентов | `devstack/teamcity-agent:2026.1.1-3` |
| `TEAMCITY_HOST_DRIVES` | что видно сборкам как `/host`; задавать, только чтобы ограничить одной папкой (например `D:/work`) | все диски ПК — `/run/desktop/mnt/host` |
| `HOST_TZ` | часовой пояс агентов; обычно не нужен — bat-файлы сами берут пояс этого ПК | пояс ПК (из bat), иначе UTC |

### Диски компьютера в TeamCity

Docker Desktop (WSL2) сам держит все диски Windows в `/run/desktop/mnt/host`; это место смонтировано в сервер и агентов как `/host`, только на чтение. Буквы дисков нигде не прописаны: на другом ПК будут видны его диски. Диск, подключённый после запуска TeamCity (флешка), появится после `stop.bat` + `start.bat`. Записывать на диски ПК сборки не могут.

## Агенты

### Что на агенте

Образ — официальный `jetbrains/teamcity-agent:2026.1.1` плюс JDK, Maven, `rsync` и `devstack-sync` ([agent/Dockerfile](agent/Dockerfile), [agent/devstack-sync](agent/devstack-sync)). Переменные называются, как у типового Linux-агента TeamCity (`JDK_11_0_x64` и т.д.), поэтому готовые настройки сборок работают без правок.

| Что | Параметр для сборки | Путь |
|---|---|---|
| JDK 1.8 | `%env.JDK_1_8_x64%` (а также `JDK_1_8`, `JDK_18`, `JDK_18_x64`) | `/opt/jdk/8` |
| JDK 11 | `%env.JDK_11_0_x64%` (а также `JDK_11`, `JDK_11_x64`, `JDK_11_0`) | `/opt/jdk/11` |
| JDK 17 | `%env.JDK_17_0_x64%` (а также `JDK_17`, `JDK_17_x64`, `JDK_17_0`) | `/opt/jdk/17` |
| JDK 21 (по умолчанию, `JAVA_HOME`) | `%env.JDK_21_0_x64%` | `/opt/jdk/21` |
| Maven 3.6.3 / 3.9.16 | `%teamcity.tool.maven.3.6.3%` / `%teamcity.tool.maven3_9%`, в командной строке — `mvn` (3.9) | `/opt/maven/...` |
| Docker, docker compose | шаги Command Line, Testcontainers | сокет Docker Desktop |
| `devstack-sync <папка>` | синхронизация папки ПК в рабочую папку сборки (рецепт «Локальная папка») | `/usr/local/bin` |

Docker в сборках — это Docker Desktop этого ПК: контейнеры из сборок и Testcontainers появляются рядом с остальными. Для Testcontainers уже задано `TESTCONTAINERS_HOST_OVERRIDE=host.docker.internal`. Ограничение: в `docker run -v` / `docker compose` из сборки пути bind-монтирования считаются на стороне Docker Desktop, а не агента, поэтому монтировать рабочую папку сборки так не получится — используйте `docker cp` или тома.

**Часовой пояс агентов — как у этого ПК.** `start-all.bat`, `start-cicd.bat`, `menu.bat` и `teamcity\start.bat` перед запуском определяют пояс Windows (служебный `teamcity\_tz.bat`, например `Europe/Moscow`) и передают его агентам как `TZ`: время в сборках и тестах совпадает с часами ПК, на другом компьютере будет его пояс. Если запускать `docker compose` вручную, без bat-файлов, агенты получат `HOST_TZ` из `.env` или UTC. Сменился пояс на ПК — `teamcity\stop.bat` + `teamcity\start.bat`.

### Добавить агента

Из UI TeamCity новый агент-контейнер создать нельзя: в UI агентов только авторизуют, включают/выключают и раскладывают по пулам (создавать агентов из UI умеют только облачные профили — Kubernetes, AWS и т.п.).

Агентами управляет `menu.bat`, пункт **10 «Агенты CI/CD»**. Там сначала TeamCity (статус, запуск, остановка, перезапуск сервера, логи, открыть в браузере — пункты 1–5), затем статус трёх агентов (работает / остановлен / не добавлен) и действия с ними:

| Пункт | Что делает |
|---|---|
| 6. Добавить и запустить новый агент | создаёт первый свободный из `teamcity-agent-2`, `teamcity-agent-3` и запускает его; предлагает открыть в браузере страницу неавторизованных агентов |
| 7–9. Запустить / остановить / перезапустить | агента по номеру 1–3 |
| 10. Логи агента | последние 100 строк |
| 11. Удалить агента | только 2 или 3: удаляет контейнер и по желанию его тома (авторизацию, рабочие папки, кеши) |
| 12. Открыть агентов в TeamCity | http://localhost:8111/agents |

Новый агент один раз авторизуется в TeamCity: **Agents → Unauthorized → Authorize**. Добавленные агенты запоминаются сами (по созданным контейнерам): `start-all.bat`, `stop-all.bat`, `teamcity\start.bat` и `teamcity\stop.bat` поднимают и останавливают их вместе с остальными. Файл `.env` для этого не нужен. После удаления агента в TeamCity остаётся запись Disconnected — убрать её: Agents → агент → Remove.

Без меню: `docker compose up -d teamcity-agent-2` — добавить и запустить, `docker compose rm -sf teamcity-agent-2` — удалить. Агентов больше трёх: скопировать блок `teamcity-agent-3` в [docker-compose.yml](docker-compose.yml) с новым номером — но бесплатная лицензия даёт только 3 агента.

### Образ агента

Существующие образы не меняются — только создаются новые теги:

1. Правка [agent/Dockerfile](agent/Dockerfile), [agent/devstack-sync](agent/devstack-sync) или сертификаты в [agent/certs](agent/certs/README.md).
2. `build-image.bat <новый тег>`, например `build-image.bat 2026.1.1-4` — собирает **новый** тег; если тег уже есть, откажется.
3. В `.env`: `TEAMCITY_AGENT_IMAGE=devstack/teamcity-agent:2026.1.1-4` (или новый тег по умолчанию в [docker-compose.yml](docker-compose.yml)), затем `stop.bat` + `start.bat`. Авторизация и кеши агентов сохраняются. Откат — вернуть прежний тег.

Если образа с тегом из `.env` нет совсем (например, после клонирования), `start.bat` один раз соберёт его сам.

Образы: `2026.1.1-1` — JDK и Maven; `2026.1.1-2` — плюс `rsync` и первая версия `devstack-sync`; `2026.1.1-3` (по умолчанию) — `devstack-sync` не переносит вывод Gradle у модулей без своего `build.gradle` и не копирует `gradlew` заново на каждой сборке.

## Сборки

Откуда сборка берёт код, задаёт **VCS root** (Version Control Settings конфигурации):

| Источник кода | VCS root | Что собирается |
|---|---|---|
| Git-сервер (Bitbucket) по SSH | `ssh://git@<сервер>:<порт>/<проект>/<репо>.git`, авторизация **Uploaded Key** | закоммиченное и запушенное |
| Git по HTTPS | `https://...`, логин и пароль / токен | закоммиченное и запушенное |
| Локальный git-репозиторий на этом ПК | `file:///host/<диск>/<путь>`, например `D:\work\app` → `file:///host/d/work/app`, авторизация **Anonymous** | закоммиченное в локальном репозитории, пуш не нужен |
| Локальная папка как есть | **без VCS root**, первый шаг — рецепт «Локальная папка» с путём Windows | всё, что в папке сейчас, включая незакоммиченное |

Понять, откуда собиралась сборка: в результатах сборки вкладка **Changes** (для git — коммиты), в логе — `Checkout directory` и `VCS Root: ...` для git или строки `devstack-sync` для локальной папки.

### Bitbucket: как подключиться

Подходит Bitbucket Server / Data Center. Сервер должен быть доступен из контейнеров TeamCity по HTTPS и/или SSH. Способы:

| Способ | Нужен админ Bitbucket | Выбор репозитория | Что настроить один раз |
|---|---|---|---|
| SSH-ключ | нет | адрес вставляется вручную (кнопка **Clone** в Bitbucket → SSH) | свой ключ: публичный — в Bitbucket, приватный — в TeamCity |
| Личный HTTP access token | нет | адрес вставляется вручную (**Clone** → HTTP) | токен в Bitbucket; вводится в каждый VCS root |
| OAuth-подключение (Connections) | **да** | список всех доступных репозиториев прямо в TeamCity | Application Link в Bitbucket |

**SSH-ключ — рекомендуется: настраивается один раз на все репозитории.**

1. Создать ключ (в cmd): `ssh-keygen -t ed25519 -f %USERPROFILE%\.ssh\teamcity_bitbucket -C teamcity-local` — без пароля или с паролем (тогда он вводится в VCS root).
2. Bitbucket → аватар → **Manage account → SSH keys → Add key** — вставить содержимое `teamcity_bitbucket.pub`. Ключ получает те же права на чтение, что и ваша учётка.
3. TeamCity → Administration → **Root project → SSH Keys → Upload SSH Key** — файл `teamcity_bitbucket` (без `.pub`). Виден всем проектам.
4. Для каждого репозитория — VCS root с адресом `ssh://git@<сервер>:<порт>/<проект>/<репо>.git` и авторизацией **Uploaded Key** (ниже, «Сборка из git»).

**Личный HTTP access token.**

1. Bitbucket → аватар → **Manage account → HTTP access tokens → Create token**, права: Projects — Read, Repositories — Read (Write — если сборка будет пушить теги или нужен pre-tested commit). Токен показывается один раз.
2. TeamCity → **Create project → From a repository URL** (или *Any Git URL*): адрес `https://<сервер>/scm/<проект>/<репо>.git`, Username — ваш логин Bitbucket, Password — токен.

**OAuth-подключение — если администратор Bitbucket создаст Application Link:** Bitbucket → Administration → Application Links → Create link → *External application*, *Incoming*; Redirect URL `http://localhost:8111/oauth/bitbucketserver/accessToken.html`; права Repositories — Write. Полученные Client ID и Client secret — в TeamCity: Root project → **Connections → Add Connection → Bitbucket Server / Data Center**, Server URL `https://<сервер>`, галочку *Enable unique redirect URL* снять. Redirect URL одинаковый для всех, у кого TeamCity на `localhost:8111`, поэтому одного Application Link хватит всей команде. После этого: **Create project → Bitbucket** → вход своей учёткой → выбор любого репозитория из списка.

### Сборка из git (Bitbucket по SSH)

1. Ключ: **Administration → Projects → Root project → SSH Keys → Upload SSH Key** — приватный ключ, у которого есть доступ к Bitbucket (см. «Bitbucket: как подключиться»). Загружается один раз и виден всем подпроектам.
2. **Administration → Projects → Create project → Manually**, имя проекта.
3. В проекте **Create build configuration → Manually**, затем **VCS settings → Create VCS root**:
   - Type: **Git**;
   - Fetch URL: `ssh://git@<сервер>:<порт>/<проект>/<репо>.git`;
   - Default branch: `refs/heads/master` (или параметр `refs/heads/%BuildBranch%`, сам параметр — во вкладке Parameters);
   - Branch specification: `+:refs/heads/*` — чтобы можно было собирать и другие ветки;
   - Authentication method: **Uploaded Key**, ключ из шага 1;
   - **Test connection** → Create.
4. **Build Steps → Add build step** (или *Auto-detect build steps*):
   - **Gradle**: Gradle tasks `clean build`, *Use Gradle Wrapper* — да; **JDK home path** — `%env.JDK_11_0_x64%` (или другой JDK из таблицы выше);
   - **Maven**: Goals `clean install`; Maven selection — встроенный или *Custom* `%teamcity.tool.maven3_9%`; JDK — так же;
   - **Command Line** — любые команды, `docker`, `docker compose`, `mvn`.
5. **Triggers** (по желанию): VCS Trigger — сборка на каждый пуш; Schedule Trigger — по расписанию.
6. **Run**. Запуск с другой веткой или параметрами — кнопка **...** рядом с Run.

Быстрый вариант для HTTPS или публичного репозитория: **Create project → From a repository URL** — URL, логин и токен; TeamCity сам создаст VCS root и предложит шаги.

### Сборка из локального git-репозитория

1. **Create project → Any Git URL** (или в VCS root конфигурации).
2. URL: путь к папке репозитория в виде `file:///host/<буква диска маленькая>/<путь через />`. Например, `D:\work\my-service` → `file:///host/d/work/my-service`. Логин и пароль — пустые (Anonymous).

Собирается то, что закоммичено в локальном репозитории (пушить не нужно). TeamCity видит новые коммиты сам, VCS Trigger тоже работает.

### Сборка из локальной папки (незакоммиченный код)

Для папки, которая не в git (или когда нужно собрать её как есть, с незакоммиченным), — рецепт TeamCity **«Локальная папка»**. Он вызывает на агенте команду `devstack-sync` из образа агента: та синхронизирует папку ПК в рабочую папку сборки через `rsync`.

- Первая сборка переносит всю папку, следующие — только изменённые и удалённые файлы (на проекте из 7 тыс. файлов: первая синхронизация ~1,5 мин, повторная без изменений ~17 с — это проверка файлов на диске Windows).
- Результаты сборки на агенте сохраняются между сборками, Gradle собирает инкрементально (повторная сборка того же проекта — 30 с вместо 5 минут). Поэтому в задачах Gradle **не ставьте `clean`**: `build -x test`, а не `clean build`.
- Не переносятся: `build` с выводом Gradle (рядом `build.gradle` или внутри `tmp`/`classes`/`libs`), `target` Maven, `.git`, `.gradle`, `.idea`, `node_modules`. Папки `build` с исходниками (например, библиотеки в `resources`) переносятся.
- Исходная папка не меняется: диски ПК подключены только на чтение. `gradlew` с CRLF из Windows на агенте приводится к LF.

**Настройка конфигурации:**

1. **Create project → Proceed without repository**, в проекте **Create build configuration** — тоже без репозитория.
2. **Build Steps → Add build step** → справа в **Your recipes** — **Private recipe 'Локальная папка'** → поле **Папка проекта**: обычный путь Windows, например `D:\work\my-service` → **Save**.
3. **Add build step → Gradle**: Gradle tasks `build -x test` (без `clean`), *Use gradle wrapper*, **JDK** — `%env.JDK_17_0_x64%` и т.п. Или **Maven**: goals `install`.
4. **Run**. В логе первого шага — `devstack-sync: <папка> -> ...` и `Number of regular files transferred: N`.

Чтобы собрать другую папку — поменять путь в шаге-рецепте. Если нужна полностью чистая сборка — **Run → ...** → *Clean all files in the checkout directory before the build*.

**Рецепт на другом ПК.** Рецепт хранится в TeamCity (data directory), файл рецепта — [recipes/local-folder.yml](recipes/local-folder.yml). На новой установке: Administration → **Root project → Recipes → Upload private recipe** → этот файл. Нужен образ агента с `devstack-sync` — `2026.1.1-3` и новее (тег по умолчанию в [docker-compose.yml](docker-compose.yml)).

Та же команда работает и без рецепта — шаг **Command Line** с одной строкой `devstack-sync "D:\work\my-service"`.

### Несколько сборок

Конфигураций можно сколько угодно (лимит лицензии — 100): проект → **Create build configuration**. Повторяющиеся настройки удобно вынести в шаблон: конфигурация → Actions → **Extract template**, новые — *Create build configuration → From template*. Одновременно идёт столько сборок, сколько агентов, остальные ждут в очереди.

## Хранение логов билдов

Лог одной сборки большого проекта с тестами — **около 220 МБ** (2 млн строк: тесты пишут в INFO весь SQL), поэтому логи и артефакты хранятся не всегда. В корневом проекте (Root project → Clean-up Rules) задано базовое правило: **логи и артефакты старше N-го последнего успешного билда каждой конфигурации удаляются**. История билдов, результаты тестов и вкладка Changes остаются. По умолчанию N = 3. Очистка идёт сама каждую ночь в 3:00.

Изменить N — меню `menu.bat` → 10 «Агенты CI/CD» → 13 «Хранение логов билдов» (показывает текущее значение и спрашивает новое) или командой:

```bat
teamcity\log-retention.bat        :: показать, сколько билдов хранится
teamcity\log-retention.bat 5      :: хранить 5 последних
teamcity\log-retention.bat now    :: очистить сейчас (то же - пункт меню 14)
```

Скрипт меняет правило в `project-config.xml` корневого проекта в томе TeamCity; сервер подхватывает его сам, перезапуск не нужен. Ручной способ — Root project → Clean-up Rules → Edit у Base rule. Правило считает **успешные** билды, После изменения N старые логи исчезнут ночью или сразу после `log-retention.bat now`. Чем больше N, тем больше места занимает том `devstack_teamcity-data`.

## Графики агентов (Beszel)

http://localhost:8091 — `admin@example.com` / `admin123`. Показывает CPU, память, сеть и диск каждого контейнера (`teamcity-agent-1..3`, сервер, база) с историей. Выбран за малую нагрузку: `beszel` ~15 МБ + `beszel-agent` ~10 МБ памяти, процессор в простое 0 %. Графики очереди и числа агентов — в самом TeamCity: Administration → Diagnostics → Metrics (то же отдаёт http://localhost:8111/app/metrics для Prometheus).

Подключение агента к hub делает `_beszel-setup.bat` — его вызывают `teamcity\start.bat`, `start-all.bat` и меню после запуска контейнеров; он один раз кладёт ключ hub в общий том и добавляет систему «Docker Desktop» (`beszel-agent:45876`). Повторный запуск ничего не меняет. Если том `devstack_beszel-data` удалён — запустите `teamcity\_beszel-setup.bat` вручную.

Другие варианты, которые рассматривались: Prometheus + Grafana (уже есть в `monitoring\`, читают `/app/metrics`, но тяжелее), cAdvisor (~100 МБ, только базовый интерфейс), Netdata (200–500 МБ), Dozzle (только логи, не метрики).

## База TeamCity (Adminer)

http://localhost:8082/?pgsql=teamcity-db — система PostgreSQL и сервер `teamcity-db` уже выбраны, дальше: пользователь `teamcity`, пароль `admin123`, база `teamcity`. Adminer — один PHP-файл, ~15 МБ памяти. Менять данные вручную не стоит — только смотреть. pgAdmin из стека (http://localhost:5050) тоже подойдёт, но для `teamcity-db` в нём сервер не добавлен, и он тяжелее (~150 МБ).

## Почему сборка идёт долго

Разбор сборки большого Gradle-проекта из 14 репозиториев (52 мин):

| Этап | Время | Причина |
|---|---|---|
| Checkout 14 репозиториев | 4:49 | включено «Delete all files before build» — каждый раз полный clone по SSH |
| Очистка (`clean`) | 1:04 | лишняя при чистом checkout |
| Сборка | 6:35 | на агенте пустой кеш Gradle; в следующей, на «тёплом» кеше — 2:34 |
| `cyclonedxBom` | 2:27 | то же: 0:49 на тёплом кеше |
| **Тесты** | **37:24** | 886 тестов с Testcontainers/Postgres: сами тесты ~25 мин, остальное — старт Spring-контекстов и контейнеров |

Что ещё влияет:

- **Память Docker Desktop.** Лимит WSL2 по умолчанию — половина RAM ПК (здесь 16 из 32 ГБ). Три агента с Gradle-демонами (`org.gradle.jvmargs=-Xmx6G`), Kotlin-демон (~2,4 ГБ) и контейнеры тестов упираются в него: на агенте при замере было свободно ~100 МБ. Лимит поднимается в `%UserProfile%\.wslconfig` (`[wsl2]` → `memory=24GB`, затем `wsl --shutdown` и перезапуск Docker Desktop) или в Docker Desktop → Settings → Resources.
- **Параллельные сборки.** 12 процессоров делятся между агентами: две сборки с тестами одновременно идут заметно дольше одной.
- **Кеш Gradle у каждого агента свой** (том `devstack_teamcity-agent-N-home`): первая сборка на новом агенте всегда долгая.
- **Лог 220 МБ.** Тесты пишут INFO-вывод SQL; агент передаёт его серверу, сервер разбирает и хранит. Снизить уровень логирования можно в настройках логирования проекта (`logback` / `logging.level.*`).
- Что можно ускорить в самой конфигурации: выключить «Delete all files before build» (checkout станет инкрементальным), выключить шаги `Очистка` и `cyclonedxBom` для проверок из IDEA. Менять ли это, решать по задаче.

## Remote Run и персональные сборки из IDEA

Remote Run отправляет на TeamCity незакоммиченные изменения и собирает их как **персональную сборку**: она видна только вам, не влияет на историю и статус конфигурации.

1. Плагин: IDEA → Settings → Plugins → Marketplace → **TeamCity** (JetBrains). Если Marketplace недоступен — скачать его с самого сервера: http://localhost:8111/update/TeamCity-IDEAplugin.zip (то же — Profile → **TeamCity Tools** → IntelliJ Platform Plugin) → в IDEA *Settings → Plugins → ⚙ → Install Plugin from Disk*.
2. IDEA → **TeamCity → Log In**: сервер `http://localhost:8111`, `admin` / `admin123` (или своя учётка).
3. Нужна конфигурация, у которой VCS root совпадает с `origin` проекта в IDEA — то есть сборка из git (Bitbucket / HTTPS), а не из `file:///local` и не из локальной папки.
4. Запуск:
   - окно Commit → **Remote Run** (иконка TeamCity) или меню **Git → TeamCity → Remote Run Outgoing Changes**;
   - выбрать конфигурацию;
   - по желанию **Pre-tested commit** — IDEA закоммитит и запушит изменения только если сборка прошла.
5. Результат — в окне TeamCity в IDEA и в UI с пометкой personal (иконка с человечком).

**Если Remote Run не находит конфигурацию** («No suitable build configurations were found»):

- **Адрес `origin` должен совпадать с URL VCS root до символа.** IDEA сопоставляет репозиторий проекта и VCS root по URL: `ssh://git@<сервер>:<порт>/<проект>/<репо>` и `.../<репо>.git` для неё разные репозитории. Смотрите `git remote -v` в каждой папке проекта (если проект из нескольких репозиториев — в каждой) и приводите URL в VCS root к тому же виду. Нужна конфигурация, у которой есть VCS root для каждого репозитория с вашими изменениями.
- Конфигурация должна быть видна пользователю (в Projects) и режим checkout — не «manual».

**Если окно «Logging in to TeamCity» висит бесконечно:** в плагине TeamCity для IDEA версии 2025.07 взаимная блокировка при входе (метод входа и запрос на сервер ждут одну блокировку), сервер здесь ни при чём. Исправлено в плагине сервера 2026.1: http://localhost:8111/update/TeamCity-IDEAplugin.zip. Он требует IDEA 243.26574 и новее, а в IDEA 2024.3.4.1 сборка 243.25659 — в `plugin.xml` внутри `lib/build-server4idea-unspecified.jar` нужно заменить `since-build="243.26574"` на `since-build="243.25659"` (или поставить IDEA 2024.3.5+), затем *Install Plugin from Disk* и перезапуск IDEA.

**Чьи это изменения.** Персональная сборка записывается на пользователя TeamCity, под которым IDEA вошла на сервер (на локальном сервере по умолчанию `admin`), а не на автора коммитов в git. Чтобы видеть своё имя, создайте пользователя (Administration → Users) и войдите им в IDEA.

Персональную сборку без IDE можно поставить через REST API:

```bat
curl -u admin:admin123 -X POST -H "Content-Type: application/xml" -d "<build personal=\"true\"><buildType id=\"ID_конфигурации\"/></build>" http://localhost:8111/app/rest/buildQueue
```

## Команды

| Команда (из папки `docker_conf`) | Что делает |
|---|---|
| `teamcity\start.bat` / `teamcity\stop.bat` | запуск / остановка сервера, БД и включённых агентов |
| `teamcity\logs.bat` | лог сервера в реальном времени |
| `docker logs -f teamcity-agent-1` | лог агента |
| `docker compose restart teamcity` | перезапуск сервера |
| `docker exec -it teamcity-agent-1 bash` | консоль агента: `ls /opt/jdk`, `docker ps`, `mvn -v` |
| `docker exec -it teamcity-db psql -U teamcity` | консоль базы TeamCity |
| `teamcity\build-image.bat <тег>` | новый образ агента |
| `teamcity\log-retention.bat [N или now]` | сколько последних билдов хранят логи / задать N / очистить сейчас |
| `teamcity\_beszel-setup.bat` | подключить агента Beszel к hub (делается само при запуске) |

## Если что-то не так

- **Агент не появляется / Disconnected** — `docker logs teamcity-agent-1`; агент подключается к `http://teamcity:8111`, сервер должен быть запущен.
- **Новый агент в Unauthorized** — так и должно быть, его нужно один раз авторизовать.
- **Gradle долго качает дистрибутив** — `services.gradle.org` из этой сети медленный. Дистрибутив кешируется в томе агента, но первый раз на каждом агенте — долго. Лучше указать в `gradle-wrapper.properties` проекта ближайшее зеркало дистрибутива.
- **Сборка не достаёт до нужного сервера** (`Connection timed out`) — подсеть какой-то сети Docker совпала с подсетью, в которой находится этот сервер; см. «Сеть» в [../README.md](../README.md). Частая причина — сеть, которую создал Testcontainers в тестах и не удалил: `docker network prune`.
- **Ошибки загрузки с download.jetbrains.com (451)** в логе сервера — обновления плагинов и инструментов TeamCity из РФ не скачиваются, на сборки это не влияет.
- **`Failed to retrieve uploaded ssh key`** — в VCS root выбран ключ, которого нет в проекте или родительских проектах (Root project → SSH Keys).
- **Нужно начать с нуля** — `docker compose stop teamcity teamcity-db teamcity-agent-1` и `docker volume rm devstack_teamcity-data devstack_teamcity-db-data devstack_teamcity-agent-1-conf devstack_teamcity-agent-1-work devstack_teamcity-agent-1-home` — **удалит все настройки и историю**.
