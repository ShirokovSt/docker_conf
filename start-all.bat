@echo off
chcp 65001 >nul
cd /d "%~dp0"
call "%~dp0_tz.bat"

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)
rem сеть devstack_default с подсетью, свободной на этом ПК (один раз создаёт _net.bat)
call "%~dp0_net.bat" || (pause & exit /b 1)

echo Запуск всех контейнеров: S3-хранилища и S3 Manager, Kafka, Elasticsearch, ActiveMQ, PostgreSQL, Spark, мониторинг, конвертер, TeamCity...
docker compose up -d
rem добавленные агенты TeamCity (2, 3) - если есть
call "%~dp0_groups.bat"
if defined CI_EXTRA docker compose up -d%CI_EXTRA%
rem агент Beszel (графики контейнеров) подключается к hub один раз
call "%~dp0teamcity\_beszel-setup.bat"
echo.
docker compose ps
call "%~dp0_links.bat"
pause
