@echo off
chcp 65001 >nul
rem Логи самого Dozzle в реальном времени. Выход - Ctrl+C.

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)

docker compose -f "%~dp0..\docker-compose.yml" logs -f --tail 100 dozzle
pause
