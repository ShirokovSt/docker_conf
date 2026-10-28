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

echo Запуск всех контейнеров: S3-хранилища и S3 Manager, Kafka, Elasticsearch, ActiveMQ, PostgreSQL, Spark, мониторинг, конвертер, почта, Cassandra, Dozzle, TeamCity...
docker compose up -d
rem добавленные агенты TeamCity (2, 3) - если есть
call "%~dp0teamcity\_agents.bat"
if defined CI_EXTRA docker compose up -d%CI_EXTRA%
echo.
docker compose --profile "*" ps
call "%~dp0_links.bat"
pause
