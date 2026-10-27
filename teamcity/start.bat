@echo off
chcp 65001 >nul

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)
rem сеть devstack_default с подсетью, свободной на этом ПК (один раз создаёт _net.bat)
call "%~dp0..\_net.bat" || (pause & exit /b 1)

call "%~dp0..\_groups.bat"
call "%~dp0_agents.bat"
call "%~dp0_tz.bat"
echo Запуск TeamCity: %CI_SERVICES%%CI_EXTRA%
docker compose -f "%~dp0..\docker-compose.yml" up -d %CI_SERVICES%%CI_EXTRA%
echo.
docker compose -f "%~dp0..\docker-compose.yml" ps -a %CI_SERVICES% %CI_AGENTS%
echo.
echo   TeamCity - http://localhost:8111  admin / admin123 (готов через 1-2 минуты, ход запуска - logs.bat)
echo   Агенты   - Agent (devstack)-N: JDK 8/11/17/21, Maven 3.6.3/3.9, Docker
echo              добавить агента - menu.bat, пункт 10 "Агенты CI/CD"
echo   База TeamCity - pgAdmin http://localhost:5050, сервер teamcity-db
echo   Метрики       - Grafana http://localhost:3000, дашборд TeamCity (monitoring\start.bat)
echo   Хранение логов билдов - log-retention.bat (3 последних билда, чистится после каждого билда, меню - пункт 10)
echo   Папки этого ПК в сборках - /host, например C:\work\app = /host/c/work/app
echo   Первый запуск - принять лицензию в мастере, см. teamcity\README.md
echo.
pause
