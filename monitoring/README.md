# Мониторинг: Prometheus + Grafana для Spring Boot приложений

| | |
|---|---|
| Grafana | http://localhost:3000 — без логина, сразу открывается дашборд «Spring Boot» |
| Prometheus | http://localhost:9090, список приложений и их статус — http://localhost:9090/targets |
| Порт Spring-приложения по умолчанию | **8199** |
| Контейнеры / сервисы | `prometheus`, `grafana` |
| Версия | Prometheus 3.15.0, Grafana 12.4.12 |
| Данные | именованные тома Docker `devstack_prometheus-data` (метрики за 15 дней) и `devstack_grafana-data` (ваши дашборды и настройки) |

Запуск: `start.bat`, остановка: `stop.bat`, логи: `logs.bat`. Всё сразу — `start-all.bat` или `start-services.bat` в корне.

## Как это работает

Приложение ничего никуда не отправляет. Prometheus в Docker сам раз в 15 секунд читает `/actuator/prometheus` у приложений, запущенных на этом компьютере (через адрес `host.docker.internal`). Grafana берёт данные только из этого Prometheus. Источник данных и дашборд в Grafana уже настроены.

```
Spring-приложение (localhost:8199) ←── читает раз в 15 с ── Prometheus (Docker) ←── Grafana (Docker)
```

## Требования к Spring-приложению

Подойдёт любое Spring Boot приложение (2.x или 3.x), если в нём есть:

1. Зависимости `spring-boot-starter-actuator` и `io.micrometer:micrometer-registry-prometheus`.
2. Открытый эндпоинт: `management.endpoints.web.exposure.include=prometheus` (или `*`, или список, в котором есть `prometheus`).
3. Доступ к эндпоинту без авторизации. Проверка: откройте в браузере `http://localhost:8199/actuator/prometheus` (с context-path — `http://localhost:8199/<context-path>/actuator/prometheus`). Должен показаться текст с метриками, а не страница входа.
4. Необязательно: `management.metrics.tags.application=<имя приложения>` — тогда в Grafana можно выбирать приложение по имени (список «Приложение»).

## Порт приложения и свои порты

**По умолчанию Prometheus ждёт приложение на порту 8199**: запускайте с `server.port=8199` (в properties или `-Dserver.port=8199` в VM-опциях).

Запускаете на другом порту или несколько приложений — допишите их в [prometheus/targets.yml](prometheus/targets.yml). Prometheus перечитывает файл сам примерно раз в 30 секунд, перезапуск не нужен.

```yaml
# приложение без context-path на порту 8199 и ещё одно на 8081
- targets:
    - host.docker.internal:8199
    - host.docker.internal:8081
  labels:
    __metrics_path__: /actuator/prometheus

# приложение с server.servlet.context-path=/app на порту 8200
- targets:
    - host.docker.internal:8200
  labels:
    __metrics_path__: /app/actuator/prometheus
```

- Адрес всегда `host.docker.internal:<порт>` — это ваш компьютер, если смотреть из Docker. `localhost` здесь не подойдёт: для Prometheus это сам контейнер.
- Приложения с разным путём к эндпоинту — разные блоки `- targets:`.
- Незапущенные приложения просто будут DOWN на http://localhost:9090/targets — это нормально.

Проверка: http://localhost:9090/targets → блок `spring`, у вашего приложения статус **UP**. Если **DOWN** — в колонке Error будет причина: приложение не запущено, неверный порт или путь, 401/403 (эндпоинт под авторизацией).

## Дашборд «Spring Boot»

| Блок | Что показывает |
|---|---|
| Обзор | время работы, заполненность heap, запросы/с, ошибки 5xx/с |
| JVM | CPU процесса и системы, heap и non-heap, сборка мусора, потоки |
| HTTP | запросы/с по статусам, ошибки 4xx/5xx по URI, время ответа (среднее, максимум, 95-й перцентиль) |
| База данных и логи | пул соединений Hikari, количество error/warn в логах |

Сверху — выбор приложения и экземпляра (хост:порт), по умолчанию показываются все.

**Совместимость.** Дашборд построен на стандартных метриках Micrometer (`jvm_*`, `process_*`, `http_server_requests_seconds_*`, `hikaricp_*`, `logback_events_total`). Их имена одинаковы в Spring Boot 2.x и 3.x, так что после обновления версии Spring дашборд продолжит работать. Если у приложения каких-то метрик нет (нет Hikari, логи не на Logback), соответствующая панель просто будет пустой.

**95-й перцентиль** появится, только если в приложении включены гистограммы: `management.metrics.distribution.percentiles-histogram.http.server.requests=true`. Без этого панель пустая, а среднее и максимум работают.

## Свои метрики

Prometheus сохраняет **всё**, что приложение отдаёт в `/actuator/prometheus`, а не только то, что есть на дашборде. Новые и свои метрики (`Counter`, `Timer`, `Gauge` из кода) видны сразу:

- **Explore** (меню слева): выберите метрику из списка — график строится сразу.
- **Свой дашборд или панель**: дашборд «Spring Boot» только для чтения, поэтому откройте его → Save as → в копии Add → Visualization. Копии и свои дашборды хранятся в томе `grafana-data` и не пропадают при перезапуске.
- **Готовые дашборды из каталога Grafana**: Dashboards → New → Import → ID дашборда с grafana.com → источник данных Prometheus.

Полезные запросы PromQL (вставлять в Explore):

| Запрос | Что показывает |
|---|---|
| `up{job="spring"}` | какие приложения доступны (1) или нет (0) |
| `rate(http_server_requests_seconds_count[1m])` | запросы в секунду по каждому URI и статусу |
| `jvm_memory_used_bytes{area="heap"}` | занятая память heap по областям |
| `topk(5, max by (uri) (http_server_requests_seconds_max))` | 5 самых медленных URI |
| `{__name__=~"my_metric.*"}` | все метрики, имя которых начинается на `my_metric` |

## Запасной вариант: docker run

Выполнять в cmd из папки `docker_conf` (`%cd%` — текущая папка). Без compose Grafana не найдёт Prometheus по имени `prometheus`, поэтому сначала создаётся общая сеть.

```bat
docker network create monitoring

docker run -d ^
  --name prometheus ^
  --network monitoring ^
  -p 9090:9090 ^
  --add-host host.docker.internal:host-gateway ^
  -v "%cd%\monitoring\prometheus:/etc/prometheus/conf:ro" ^
  -v devstack_prometheus-data:/prometheus ^
  prom/prometheus:v3.15.0 ^
  --config.file=/etc/prometheus/conf/prometheus.yml --storage.tsdb.path=/prometheus --storage.tsdb.retention.time=15d

docker run -d ^
  --name grafana ^
  --network monitoring ^
  -p 3000:3000 ^
  -e GF_AUTH_ANONYMOUS_ENABLED=true ^
  -e GF_AUTH_ANONYMOUS_ORG_ROLE=Admin ^
  -e GF_AUTH_DISABLE_LOGIN_FORM=true ^
  -e GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/etc/grafana/dashboards/spring-boot.json ^
  -v "%cd%\monitoring\grafana\provisioning:/etc/grafana/provisioning:ro" ^
  -v "%cd%\monitoring\grafana\dashboards:/etc/grafana/dashboards:ro" ^
  -v devstack_grafana-data:/var/lib/grafana ^
  grafana/grafana:12.4.12
```
