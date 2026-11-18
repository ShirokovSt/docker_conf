@echo off
chcp 65001 >nul
cd /d "%~dp0"

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)

echo Остановка всех контейнеров: S3-хранилища и S3 Manager, Kafka, Elasticsearch, ActiveMQ, PostgreSQL, Spark, мониторинг, конвертер, почта, Cassandra, Dozzle, TeamCity, SonarQube...
rem --profile "*" - вместе с добавленными агентами TeamCity (2, 3), если они есть
docker compose --profile "*" stop
echo.
docker compose --profile "*" ps -a
pause
