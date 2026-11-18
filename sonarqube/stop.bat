@echo off
chcp 65001 >nul

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)

rem postgres не останавливаем: он общий для других сервисов (postgres\stop.bat)
echo Остановка sonarqube и страницы анализа...
docker compose -f "%~dp0..\docker-compose.yml" stop sonarqube-ui sonarqube
pause
