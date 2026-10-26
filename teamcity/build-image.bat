@echo off
chcp 65001 >nul
setlocal
rem Собирает НОВЫЙ образ агента TeamCity из teamcity\agent: devstack/teamcity-agent:<тег>.
rem Уже собранные теги не пересобираются - для изменений всегда новый тег (2026.1.1-2, 2026.1.1-3, ...).
rem Запуск: build-image.bat [тег]. Без тега - спросит.

set "REPO=devstack/teamcity-agent"

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)

echo Уже собранные образы агента:
docker images %REPO% --format "  {{.Repository}}:{{.Tag}}   {{.CreatedSince}}"
echo.

set "tag=%~1"
if not defined tag set /p "tag=Новый тег (например 2026.1.1-2): "
if not defined tag (
    echo [!] Тег не задан.
    pause
    exit /b 1
)

docker image inspect "%REPO%:%tag%" >nul 2>&1
if not errorlevel 1 (
    echo [!] Образ %REPO%:%tag% уже есть. Существующие образы не меняем - укажите новый тег.
    pause
    exit /b 1
)

echo Сборка %REPO%:%tag% ...
docker build -t "%REPO%:%tag%" "%~dp0agent"
if errorlevel 1 (
    echo [!] Сборка не удалась, см. вывод выше.
    pause
    exit /b 1
)

echo.
echo Готово: %REPO%:%tag%
echo Чтобы агенты работали на нём:
echo   1. в файле docker_conf\.env укажите  TEAMCITY_AGENT_IMAGE=%REPO%:%tag%
echo   2. пересоздайте агентов: teamcity\stop.bat, затем teamcity\start.bat
echo Авторизация агентов и их кеши сохраняются. Вернуться на старый образ - вернуть прежний тег в .env.
pause
