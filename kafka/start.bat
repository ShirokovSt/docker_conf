@echo off
chcp 65001 >nul

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)

echo Запуск kafka kafka-ui...
docker compose -f "%~dp0..\docker-compose.yml" up -d kafka kafka-ui
echo.
echo   Kafka UI  - http://localhost:8080
echo   Bootstrap - localhost:9092 (с хоста), kafka:29092 (из контейнеров)
echo.
pause
