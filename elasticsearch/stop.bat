@echo off
chcp 65001 >nul

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)

echo Остановка elasticsearch kibana...
docker compose -f "%~dp0..\docker-compose.yml" stop elasticsearch kibana
pause
