@echo off
chcp 65001 >nul
cd /d "%~dp0"
call "%~dp0teamcity\_tz.bat"

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)
rem сеть devstack_default с подсетью, свободной на этом ПК (один раз создаёт _net.bat)
call "%~dp0_net.bat" || (pause & exit /b 1)

:menu
rem Группы читаются при каждом показе меню: правки _groups.bat видны без перезапуска меню.
rem _groups.bat только задаёт переменные, Docker не вызывает - меню перерисовывается сразу.
call "%~dp0_groups.bat"
cls
echo ===================== Локальные сервисы =====================
echo.
echo   1. Запустить ВСЁ
echo   2. Остановить ВСЁ
echo   3. Статус
echo.
echo   4. Запустить S3-хранилища
echo   5. Остановить S3-хранилища
echo   6. Запустить сервисы - Kafka, Elasticsearch, ActiveMQ, PostgreSQL, Spark, мониторинг, конвертер, почта, Cassandra, Dozzle
echo   7. Остановить сервисы
echo   8. Запустить CI/CD - TeamCity, его БД и агенты
echo   9. Остановить CI/CD
echo  10. Агенты CI/CD - статус, добавить новый, запустить, удалить
echo.
echo  11. Запустить один
echo  12. Остановить один
echo  13. Перезапустить один
echo  14. Логи одного - последние 200 строк
echo.
echo  15. Открыть веб-интерфейс
echo  16. Ссылки и ключи
echo.
echo   0. Выход
echo.
set "choice="
set /p "choice=Выберите пункт: "

if "%choice%"=="1"  goto start_all
if "%choice%"=="2"  goto stop_all
if "%choice%"=="3"  goto status
if "%choice%"=="4"  set "group=%S3_SERVICES%"  & set "action=start" & goto group
if "%choice%"=="5"  set "group=%S3_SERVICES%"  & set "action=stop"  & goto group
if "%choice%"=="6"  set "group=%APP_SERVICES%" & set "action=start" & goto group
if "%choice%"=="7"  set "group=%APP_SERVICES%" & set "action=stop"  & goto group
if "%choice%"=="8"  goto ci_start
if "%choice%"=="9"  set "group=%CI_SERVICES% %CI_AGENTS%" & set "action=stop" & goto group
if "%choice%"=="10" goto cicd
if "%choice%"=="11" set "action=start"   & goto pick
if "%choice%"=="12" set "action=stop"    & goto pick
if "%choice%"=="13" set "action=restart" & goto pick
if "%choice%"=="14" set "action=logs"    & goto pick
if "%choice%"=="15" goto open_ui
if "%choice%"=="16" goto links
if "%choice%"=="0"  exit /b 0
goto menu

:start_all
docker compose up -d
call "%~dp0teamcity\_agents.bat"
if defined CI_EXTRA docker compose up -d%CI_EXTRA%
docker compose --profile "*" ps
pause
goto menu

:stop_all
rem --profile "*" - вместе с добавленными агентами TeamCity
docker compose --profile "*" stop
pause
goto menu

:status
docker compose --profile "*" ps -a
pause
goto menu

:ci_start
rem CI/CD вместе с добавленными агентами (2, 3), если есть
call "%~dp0teamcity\_agents.bat"
set "group=%CI_SERVICES%%CI_EXTRA%"
set "action=start"
goto group

:links
call "%~dp0_links.bat"
pause
goto menu

:group
if "%action%"=="start" docker compose up -d %group%
if "%action%"=="stop"  docker compose stop %group%
docker compose ps -a %group%
pause
goto menu

:open_ui
echo.
echo   1. S3 Manager - все хранилища   2. minio   3. rustfs   4. seaweedfs - Filer и Master
echo   5. Kafka UI   6. Kibana   7. ActiveMQ   8. pgAdmin   9. Spark UI   10. Файлы Spark
echo   11. Grafana   12. Prometheus   13. Конвертер - Swagger   14. TeamCity   15. Почта - Mailpit
echo   16. Cassandra   17. Логи всех контейнеров - Dozzle
echo   18. все сразу
echo   Enter - назад
echo.
set "n="
set /p "n=Что открыть: "
if "%n%"=="1" start "" http://localhost:9006
if "%n%"=="2" start "" http://localhost:9001
if "%n%"=="3" start "" http://localhost:9003
if "%n%"=="4" start "" http://localhost:8888 & start "" http://localhost:9333
if "%n%"=="5" start "" http://localhost:8080
if "%n%"=="6" start "" http://localhost:5601
if "%n%"=="7" start "" http://localhost:8161/admin
if "%n%"=="8" start "" http://localhost:5050
if "%n%"=="9" start "" http://localhost:4040
if "%n%"=="10" start "" http://localhost:8090
if "%n%"=="11" start "" http://localhost:3000
if "%n%"=="12" start "" http://localhost:9090/targets
if "%n%"=="13" start "" http://localhost:8095/swagger-ui.html
if "%n%"=="14" start "" http://localhost:8111
if "%n%"=="15" start "" http://localhost:8025
if "%n%"=="16" start "" http://localhost:8097
if "%n%"=="17" start "" http://localhost:8098
if "%n%"=="18" goto open_all
goto menu

:open_all
for %%u in (9006 9001 9003 8888 9333 8080 5601 5050 4040 8090 3000 9090 8111 8025 8097 8098) do start "" http://localhost:%%u
start "" http://localhost:8161/admin
start "" http://localhost:8095/swagger-ui.html
goto menu

:pick
echo.
echo   S3:       1. minio   2. rustfs   3. zenko   4. s3proxy   5. seaweedfs
echo   Сервисы:  6. kafka + kafka-ui   7. elasticsearch + kibana   8. activemq   10. postgres + pgadmin
echo             11. spark + spark-files   12. prometheus + grafana   13. converter   14. CI/CD - TeamCity, БД, агенты
echo             15. mailpit - тестовая почта   16. cassandra + UI
echo             17. dozzle - логи всех контейнеров
echo   UI:       9. s3manager - общий веб-интерфейс S3
echo   При запуске хранилища 1-5 вместе с ним поднимается s3manager.
echo   Enter - назад
echo.
set "svc="
set "is_s3="
set "n="
set /p "n=Сервис: "
if "%n%"=="1" set "svc=minio"     & set "is_s3=1"
if "%n%"=="2" set "svc=rustfs"    & set "is_s3=1"
if "%n%"=="3" set "svc=zenko"     & set "is_s3=1"
if "%n%"=="4" set "svc=s3proxy"   & set "is_s3=1"
if "%n%"=="5" set "svc=seaweedfs" & set "is_s3=1"
if "%n%"=="6" set "svc=kafka kafka-ui"
if "%n%"=="7" set "svc=elasticsearch kibana"
if "%n%"=="8" set "svc=activemq"
if "%n%"=="9" set "svc=s3manager"
if "%n%"=="10" set "svc=postgres pgadmin"
if "%n%"=="11" set "svc=spark spark-files"
if "%n%"=="12" set "svc=prometheus grafana"
if "%n%"=="13" set "svc=converter"
if "%n%"=="14" set "svc=%CI_SERVICES% %CI_AGENTS%"
if "%n%"=="15" set "svc=mailpit"
if "%n%"=="16" set "svc=cassandra cassandra-ui"
if "%n%"=="17" set "svc=dozzle"
if not defined svc goto menu
if "%action%"=="start" if defined is_s3 set "svc=%svc% s3manager"
rem CI/CD: запускаются только созданные агенты 2, 3 (остальные действия - со всеми)
if "%n%"=="14" if "%action%"=="start" goto pick_ci_start
:pick_run

if "%action%"=="start"   docker compose up -d %svc%
if "%action%"=="stop"    docker compose stop %svc%
if "%action%"=="restart" docker compose restart %svc%
if "%action%"=="logs"    docker compose logs --tail 200 %svc%
pause
goto menu

:pick_ci_start
call "%~dp0teamcity\_agents.bat"
set "svc=%CI_SERVICES%%CI_EXTRA%"
goto pick_run

:cicd
call "%~dp0_groups.bat"
cls
echo ===================== CI/CD: TeamCity и агенты =====================
echo.
call :tc_line
call :log_line
echo.
echo   1. Запустить TeamCity - сервер, БД, агенты
echo   2. Остановить TeamCity
echo   3. Перезапустить сервер TeamCity
echo   4. Логи сервера - последние 200 строк
echo   5. Открыть TeamCity в браузере
echo.
echo   Агенты TeamCity - бесплатная лицензия, до 3 агентов
for %%n in (1 2 3) do call :agent_line %%n
echo.
echo   6. Добавить и запустить новый агент
echo   7. Запустить агента           8. Остановить агента
echo   9. Перезапустить агента      10. Логи агента - последние 100 строк
echo  11. Удалить агента - 2 или 3
echo  12. Открыть агентов в TeamCity
echo  13. Хранение логов билдов - для скольких последних билдов хранить
echo  14. Очистить старые логи сейчас
echo  15. База TeamCity - pgAdmin      16. Метрики TeamCity - Grafana
echo.
echo   Новый агент один раз авторизуется в TeamCity: Agents - Unauthorized - Authorize.
echo   Enter - назад
echo.
set "a="
set /p "a=Выберите: "
if not defined a goto menu
if "%a%"=="1" goto cicd_start
if "%a%"=="2" goto cicd_stop
rem перезапуск TeamCity - пересоздание контейнера: restart не перечитывает .env (TEAMCITY_HOST_DIR и др.),
rem данные в томах сохраняются; --no-deps - базу teamcity-db не трогаем
if "%a%"=="3" (
    docker compose up -d --force-recreate --no-deps teamcity
    pause
    goto cicd
)
if "%a%"=="4" (
    docker compose logs --tail 200 teamcity
    pause
    goto cicd
)
if "%a%"=="5" start "" http://localhost:8111 & goto cicd
if "%a%"=="6" goto agent_new
if "%a%"=="12" start "" http://localhost:8111/agents & goto cicd
if "%a%"=="13" goto log_keep
if "%a%"=="14" (
    call "%~dp0teamcity\log-retention.bat" now
    pause
    goto cicd
)
if "%a%"=="15" goto cicd_db
if "%a%"=="16" goto cicd_metrics
set "act="
if "%a%"=="7"  set "act=start"
if "%a%"=="8"  set "act=stop"
if "%a%"=="9"  set "act=restart"
if "%a%"=="10" set "act=logs"
if "%a%"=="11" set "act=delete"
if not defined act goto cicd
set "n="
set /p "n=Номер агента (1-3): "
if not "%n%"=="1" if not "%n%"=="2" if not "%n%"=="3" goto cicd
if "%act%"=="delete"  goto agent_delete
if "%act%"=="start"   docker compose up -d teamcity-agent-%n%
if "%act%"=="stop"    docker compose stop teamcity-agent-%n%
if "%act%"=="restart" docker compose up -d --force-recreate --no-deps teamcity-agent-%n%
if "%act%"=="logs"    docker compose logs --tail 100 teamcity-agent-%n%
pause
goto cicd
:cicd_start
call "%~dp0teamcity\_agents.bat"
docker compose up -d %CI_SERVICES%%CI_EXTRA%
echo.
echo   TeamCity - http://localhost:8111 (admin / admin123), готов через 1-2 минуты.
echo   База TeamCity - пункт 15 (pgAdmin), метрики - пункт 16 (Grafana).
pause
goto cicd

:cicd_stop
docker compose stop %CI_SERVICES% %CI_AGENTS%
pause
goto cicd

:cicd_db
rem pgAdmin из группы сервисов, сервер teamcity-db в нём уже добавлен; основной postgres не нужен
docker compose up -d pgadmin
echo   pgAdmin - http://localhost:5050, слева Servers - teamcity-db (TeamCity).
start "" http://localhost:5050
pause
goto cicd

:cicd_metrics
rem метрики сервера TeamCity читает Prometheus из группы сервисов (monitoring), показывает Grafana
docker compose up -d prometheus grafana
echo   Grafana - дашборд TeamCity. Первые точки появятся через 15-30 секунд.
start "" http://localhost:3000/d/teamcity
pause
goto cicd

:log_keep
call "%~dp0teamcity\log-retention.bat"
set "k="
set /p "k=Для скольких последних билдов хранить логи (Enter - не менять, рекомендуется 3): "
if defined k call "%~dp0teamcity\log-retention.bat" %k%
pause
goto cicd

:agent_new
rem первый номер из 2, 3, для которого контейнера ещё нет
set "n="
for %%k in (2 3) do if not defined n (docker container inspect teamcity-agent-%%k >nul 2>&1 || set "n=%%k")
if not defined n (
    echo   Все 3 агента уже добавлены - это предел бесплатной лицензии TeamCity.
    pause
    goto cicd
)
echo Добавляю агента %n%: teamcity-agent-%n% ...
docker compose up -d teamcity-agent-%n%
echo.
echo   Агент Agent (devstack)-%n% появится в TeamCity через 1-2 минуты в Agents - Unauthorized.
echo   Его нужно один раз авторизовать: кнопка Authorize.
set "yn="
set /p "yn=Открыть неавторизованных агентов в браузере? (y/n): "
if /i "%yn%"=="y" start "" http://localhost:8111/agents/unauthorized
goto cicd

:agent_delete
if "%n%"=="1" (
    echo   Агент 1 основной, его не удаляем. Остановить - пункт 8.
    pause
    goto cicd
)
docker compose rm -sf teamcity-agent-%n%
set "yn="
set /p "yn=Удалить и данные агента - авторизацию, рабочие папки, кеши Gradle и Maven? (y/n): "
if /i "%yn%"=="y" docker volume rm devstack_teamcity-agent-%n%-conf devstack_teamcity-agent-%n%-work devstack_teamcity-agent-%n%-home
echo.
echo   В TeamCity агент останется в списке как Disconnected - убрать: Agents - агент - Remove.
pause
goto cicd

:log_line
rem строка про хранение логов (если сервер запущен)
set "k="
for /f "delims=" %%v in ('docker exec -i teamcity sh -s -- get ^< "%~dp0teamcity\log-retention.sh" 2^>nul') do set "k=%%v"
if defined k echo   Логи билдов хранятся для %k% последних билдов - пункт 13
exit /b 0

:tc_line
rem строка статуса сервера TeamCity
set "st=не создан"
for /f "delims=" %%s in ('docker container inspect -f "{{.State.Status}}" teamcity 2^>nul') do set "st=%%s"
if "%st%"=="running" set "st=работает"
if "%st%"=="exited"  set "st=остановлен"
echo   TeamCity - http://localhost:8111 - %st%
exit /b 0

:agent_line
rem строка статуса агента %1
set "st=не добавлен"
for /f "delims=" %%s in ('docker container inspect -f "{{.State.Status}}" teamcity-agent-%1 2^>nul') do set "st=%%s"
if "%st%"=="running" set "st=работает"
if "%st%"=="exited"  set "st=остановлен"
if "%st%"=="created" set "st=создан, не запущен"
echo   Агент %1 - Agent (devstack)-%1 - %st%
exit /b 0
