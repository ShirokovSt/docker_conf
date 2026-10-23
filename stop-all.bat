@echo off
chcp 65001 >nul
cd /d "%~dp0"

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)

echo Остановка всех контейнеров: S3-хранилища и S3 Manager, Kafka, Elasticsearch, ActiveMQ, PostgreSQL, Spark...
docker compose stop
echo.
docker compose ps -a
pause
