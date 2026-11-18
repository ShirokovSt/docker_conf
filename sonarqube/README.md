# SonarQube — статический анализ кода

SonarQube проверяет исходный код, не запуская приложение: баги, уязвимости, code smells, дублирование и покрытие тестами. Результаты — в веб-интерфейсе, по проекту, файлу и строке.

| | |
|---|---|
| SonarQube | http://localhost:9010 — `admin` / `admin123`; из контейнеров (TeamCity) — `http://sonarqube:9000` |
| Страница анализа | http://localhost:9011 — выбрать папку проекта, запустить, следить за ходом, открыть отчёт |
| Из командной строки | `analyze.bat <папка проекта> [notests] [JDK] [ключ проекта]` |
| Версия | SonarQube Community Build 26.10 |
| Данные | база `sonarqube` в общем PostgreSQL; тома `devstack_sonarqube-*` (плагины, индекс, логи), `devstack_sonarqube-ui-data` (токен, история анализов) |
| Память | SonarQube ~2 ГБ, страница анализа ~0,1 ГБ |

Запуск: `start.bat`, остановка: `stop.bat`, логи: `logs.bat`. Из корня — `start-code.bat` / `stop-code.bat` или `menu.bat` → 11–12. Первый запуск — 1–3 минуты. SonarQube запускается вместе со страницей анализа (`sonarqube-ui`): она его и настраивает.

## Как анализировать

Кнопки запуска в самом SonarQube нет: сервер принимает отчёт сканера, а сканер работает там, где лежит код. Эту роль выполняет страница анализа.

**Страница http://localhost:9011** (`menu.bat` → 17 → 19):
1. **+ Новый анализ** → **Выбрать папку…** — окно выбора папки: диски, переход по папкам (двойной клик), путь можно вставить в строку сверху; проекты помечены `Maven` / `Gradle`.
2. Тесты (нужны для покрытия), JDK (по умолчанию 21; 17, 11, 8 или любая другая), ключ проекта (необязательно — по умолчанию из сборки: `groupId:artifactId` / `group:имя`).
3. **Запустить анализ** — лог идёт вживую; **Остановить** прерывает сборку.
4. После отправки видно, как SonarQube обрабатывает отчёт и прошёл ли Quality Gate; **Открыть отчёт** — проект в SonarQube.
5. Слева — **все проекты SonarQube** (в том числе проанализированные не со страницы) и запуски со страницы. В проекте — Quality Gate и метрики, история анализов из SonarQube, повторный запуск (папку проекта, если она неизвестна, страница спросит) и последние 10 запусков со страницы с логами.
6. Анализы разных проектов могут идти **одновременно**; сколько — поле «Одновременно анализов» вверху страницы (по умолчанию 3, каждая сборка — отдельная JVM, нужна память). Одну папку дважды сразу не запустить.

**Командная строка:**

```bat
sonarqube\analyze.bat C:\work\my-service
sonarqube\analyze.bat C:\work\my-service notests 17
sonarqube\analyze.bat C:\work\my-service 8 my-project-key
```

Как это устроено:
- Тип проекта определяется сам: есть `pom.xml` — Maven, иначе `build.gradle(.kts)` / `settings.gradle(.kts)` — Gradle. Проект в SonarQube создаётся при первом анализе.
- **pom.xml и build.gradle не меняются.** Сканер SonarQube и JaCoCo (покрытие) подключаются при запуске: у Maven — именами целей плагинов, у Gradle — init-скриптом, который создаёт [ui/analyze.sh](ui/analyze.sh).
- Сборка идёт в контейнере `sonarqube-build-*` с выбранной JDK (`maven:3.9.16-eclipse-temurin-<JDK>`, `gradle:<версия>-jdk<JDK>`; у Gradle с wrapper — версия Gradle проекта) и пишет в `target` / `build` проекта. Подключаются `%USERPROFILE%\.m2` (settings.xml, зависимости) и `%USERPROFILE%\.gradle\gradle.properties`.
- Кеш Gradle — тома `devstack-gradle-cache` (основной) и `devstack-gradle-cache-2`, `-3`… для одновременных сборок: один кеш Gradle не может использоваться из нескольких контейнеров сразу. Второй кеш при первом использовании скачивает зависимости заново.
- Тесты с Testcontainers работают: сборке доступен Docker этого ПК. Упавшие тесты анализ не останавливают.
- Сканеру нужна Java 11+: при JDK 8 сборка и тесты идут на 8, отчёт отправляется вторым шагом на JDK 11.
- **Gradle старше 7.3** (плагин SonarQube с ним не работает): проект собирается своим Gradle на JDK не выше 11, отчёт отправляет SonarScanner CLI — исходники, классы и покрытие берутся из папок модулей (`src/main|test/java|kotlin`, `build/classes`, отчёты JaCoCo), рабочая папка сканера — `.scannerwork` в проекте. Ключ по умолчанию — `rootProject.name`.
- Сборке нужен интернет (Maven Central, Gradle, Docker Hub) или ваш Nexus.
- Другая JDK — любым числом, если на Docker Hub есть образ с ней. Какие папки видны странице — `SONAR_HOST_DIR` в `.env` (по умолчанию все диски).

**Из IDEA или консоли** — с токеном анализа: `docker exec sonarqube-ui cat /data/token`.

```bat
mvn org.jacoco:jacoco-maven-plugin:prepare-agent verify org.jacoco:jacoco-maven-plugin:report org.sonarsource.scanner.maven:sonar-maven-plugin:sonar -Dsonar.host.url=http://localhost:9010 -Dsonar.token=<токен>
```

**Из TeamCity:** шаг Maven с целями `verify org.sonarsource.scanner.maven:sonar-maven-plugin:sonar` и параметрами `-Dsonar.host.url=http://sonarqube:9000 -Dsonar.token=%sonar.token%` (параметр типа Password; `-Dsonar.qualitygate.wait=true` — билд падает, если Quality Gate не пройден).

## Что настроено автоматически

[ui/setup.sh](ui/setup.sh) при каждом запуске `sonarqube-ui` делает то, что ещё не сделано:
- пароль `admin123` вместо обязательной смены при первом входе (пишется в базу: через UI и API пароль короче 12 символов не задать; сменённый в UI не трогается);
- Server base URL `http://localhost:9010` — ссылки на отчёты ведут на адрес для браузера;
- токен анализа `devstack` в томе `sonarqube-ui-data`; отозвали — выпустится новый.

Базу `sonarqube` создаёт одноразовый `sonarqube-dbinit` ([db-init.sh](db-init.sh)), в `docker compose ps` он `Exited (0)`.

## Как читать результаты

- **Overview** — Quality Gate и оценки A–E: Reliability (баги), Security (уязвимости), Maintainability (code smells), Coverage, Duplications. Вкладки **New Code** / **Overall Code**.
- **Issues** — замечания с фильтрами; у каждого — строка кода и как исправить. Ложное срабатывание — **False positive**, осознанное — **Accept**.
- **Security Hotspots** — места для ручной проверки.
- Стандартный Quality Gate «Sonar way» проверяет только новый код: нет новых замечаний, покрытие ≥ 80 %, дублирование ≤ 3 %.
- **Покрытие** считает JaCoCo во время тестов; без тестов (`notests`) оно 0 %.

Настройка: Quality Profiles (наборы правил), Quality Gates, исключения — `sonar.exclusions`, `sonar.coverage.exclusions` в pom или `-D`. Community Build хранит одну ветку на проект.

## Elasticsearch

Внутри контейнера `sonarqube` работает встроенный Elasticsearch — поисковый индекс SonarQube (отдельного контейнера нет). Параметры в `docker-compose.yml`: heap 512 МБ (`SONAR_SEARCH_JAVAOPTS=-Xms512m -Xmx512m`), проверки ОС при старте выключены (`SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true`). Индекс хранится в томе `devstack_sonarqube-data` и восстанавливается из базы.

## Запасной вариант: docker run

В cmd из папки `docker_conf`, при запущенном `postgres` и существующей базе `sonarqube`:

```bat
docker run -d ^
  --name sonarqube ^
  --network devstack_default ^
  -p 9010:9000 ^
  -e SONAR_JDBC_URL=jdbc:postgresql://postgres:5432/sonarqube ^
  -e SONAR_JDBC_USERNAME=postgres ^
  -e SONAR_JDBC_PASSWORD=admin123 ^
  -e "SONAR_SEARCH_JAVAOPTS=-Xms512m -Xmx512m" ^
  -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true ^
  -v devstack_sonarqube-data:/opt/sonarqube/data ^
  -v devstack_sonarqube-extensions:/opt/sonarqube/extensions ^
  -v devstack_sonarqube-logs:/opt/sonarqube/logs ^
  sonarqube:26.10.0.133078-community
```

Без `sonarqube-ui` пароль (не короче 12 символов) и токен задаются вручную в UI.
