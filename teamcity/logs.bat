@echo off
chcp 65001 >nul
rem Логи сервера TeamCity в реальном времени. Выход - Ctrl+C.
rem Логи агента: docker logs -f teamcity-agent-1 (2, 3). Файлы логов сервера - папка teamcity\logs.

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)

docker compose -f "%~dp0..\docker-compose.yml" logs -f --tail 100 teamcity
pause
