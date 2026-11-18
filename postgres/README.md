# PostgreSQL 16 + pgAdmin

| | |
|---|---|
| Веб-интерфейс (pgAdmin 4) | http://localhost:5050 — без логина, серверы «devstack postgres» и «teamcity-db (TeamCity)» уже добавлены и подключаются без пароля |
| Подключение с этого ПК | `localhost:5434` |
| Подключение из других контейнеров compose | `postgres:5432` |
| Пользователь / пароль | `postgres` / `admin123` |
| БД по умолчанию | `postgres` |
| Другие базы | `sonarqube` — база [SonarQube](../sonarqube/README.md), создаётся сама при первом запуске SonarQube; вручную не править |
| Контейнеры / сервисы | `postgres`, `pgadmin` |
| Версия | PostgreSQL 16.15, pgAdmin 9.18 |
| Данные | именованный том Docker `devstack_postgres-data` (не папка, см. ниже) |

Запуск: `start.bat` (PostgreSQL + pgAdmin), остановка: `stop.bat`, логи: `logs.bat`, бэкап: `backup.bat`. Всё сразу — `start-all.bat` или `start-services.bat` в корне.

## Где хранятся данные

У остальных сервисов данные лежат в папке `<сервис>/data`. У PostgreSQL так нельзя: при запуске он выставляет на свою папку права `0700`, а папки с диска Windows этого не поддерживают, и база не инициализируется. Поэтому данные PostgreSQL и настройки pgAdmin хранятся в **именованных томах Docker** `devstack_postgres-data` и `devstack_pgadmin-data` внутри Docker Desktop.

- Данные **сохраняются** при остановке и перезапуске, при пересоздании контейнера, при `docker compose down` и обновлении образа.
- Данные **удаляются** только при `docker compose down -v` (флаг `-v` удаляет тома) или `docker volume rm devstack_postgres-data`. Не используйте их, если данные нужны.
- Чтобы сохранить данные в файл (перенос на другой ПК, страховка), сделайте `backup.bat` — см. ниже.

## pgAdmin

Откройте http://localhost:5050, слева: **Servers → devstack postgres**.

| Что сделать | Где |
|---|---|
| Создать базу | ПКМ по **Databases** → Create → Database |
| Создать схему | база → ПКМ по **Schemas** → Create → Schema |
| Создать таблицу | база → Schemas → схема → ПКМ по **Tables** → Create → Table. Вкладка **Columns** — колонки и типы, **Constraints** — первичный ключ, внешние ключи, unique, check. |
| Изменить таблицу | ПКМ по таблице → Properties |
| Посмотреть и отредактировать данные | ПКМ по таблице → View/Edit Data → All Rows. Редактирование прямо в сетке, сохранение — F6 или кнопка Save. |
| Выполнить SQL | ПКМ по базе → **Query Tool**, выполнение — F5 |
| Схема связей таблиц | ПКМ по базе или схеме → **ERD For Database / Schema** |
| Индексы, представления, функции, последовательности | соответствующие узлы в дереве схемы → ПКМ → Create |
| Бэкап и восстановление одной базы | ПКМ по базе → Backup… / Restore… |
| Пользователи и права | ПКМ по **Login/Group Roles** → Create; права — в Properties объекта, вкладка Security |

Список серверов pgAdmin берёт из [pgadmin/servers.json](pgadmin/servers.json) при каждом старте, пароль — из [pgadmin/pgpass](pgadmin/pgpass). Если меняете пароль `postgres`, поправьте его в `docker-compose.yml` и в `pgpass`.

**База TeamCity.** Второй сервер в списке — **teamcity-db (TeamCity)**: база `teamcity` из [teamcity](../teamcity/README.md), пользователь `teamcity`. Подключается, когда запущен TeamCity. pgAdmin не зависит от основного PostgreSQL и может работать один: `docker compose up -d pgadmin` или `menu.bat` → 10 «Агенты CI/CD» → «База TeamCity». Данные TeamCity лучше только смотреть: ручные правки могут сломать сервер.

## Консоль psql

| Команда | Что делает |
|---|---|
| `docker exec -it postgres psql -U postgres` | открыть psql, выход — `\q` |
| `docker exec -it postgres psql -U postgres -d mydb` | открыть psql в базе `mydb` |
| `\l` | список баз |
| `\c mydb` | переключиться на базу |
| `\dn` | список схем |
| `\dt` / `\dt myschema.*` | таблицы в схеме `public` / в `myschema` |
| `\d myschema.mytable` | структура таблицы |
| `\du` | роли (пользователи) |
| `CREATE DATABASE mydb;` | создать базу |
| `CREATE SCHEMA myschema;` | создать схему в текущей базе |
| `CREATE USER app WITH PASSWORD 'app123';` | создать пользователя |
| `GRANT ALL PRIVILEGES ON DATABASE mydb TO app;` | дать права на базу |
| `docker exec postgres psql -U postgres -c "SELECT version();"` | выполнить один запрос без входа в консоль |

## Бэкап и восстановление

`backup.bat` делает полный бэкап — все базы, роли и права — в `postgres\backup\all_<дата_время>.sql`. Папка `backup` в git не попадает.

| Команда (из папки `docker_conf`) | Что делает |
|---|---|
| `postgres\backup.bat` | полный бэкап всех баз |
| `docker exec postgres psql -U postgres -f /backup/all_2026-10-22_12-00-00.sql` | восстановить полный бэкап (на пустой сервер; существующие базы дадут ошибки «already exists») |
| `docker exec postgres pg_dump -U postgres -Fc -d mydb -f /backup/mydb.dump` | бэкап одной базы |
| `docker exec postgres createdb -U postgres mydb` | создать пустую базу |
| `docker exec postgres pg_restore -U postgres -d mydb /backup/mydb.dump` | восстановить одну базу в существующую пустую базу |

Внутри контейнера папка `postgres\backup` видна как `/backup`.

## Подключение из приложения

```properties
# Spring Boot
spring.datasource.url=jdbc:postgresql://localhost:5434/postgres
spring.datasource.username=postgres
spring.datasource.password=admin123
```

DBeaver и другие клиенты: хост `localhost`, порт `5434`, база `postgres`, пользователь `postgres`, пароль `admin123`.

## Запасной вариант: docker run

Без pgAdmin, только PostgreSQL. Выполнять в cmd из папки `docker_conf` (`%cd%` — текущая папка).

```bat
docker run -d ^
  --name postgres ^
  -p 5434:5432 ^
  -v devstack_postgres-data:/var/lib/postgresql/data ^
  -v "%cd%\postgres\backup:/backup" ^
  -e POSTGRES_USER=postgres ^
  -e POSTGRES_PASSWORD=admin123 ^
  postgres:16.15
```
