@echo off
chcp 65001 >nul
cd /d "%~dp0"
call "%~dp0_groups.bat"
call "%~dp0teamcity\_tz.bat"

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)
rem сеть devstack_default с подсетью, свободной на этом ПК (один раз создаёт _net.bat)
call "%~dp0_net.bat" || (pause & exit /b 1)

rem вместе с добавленными агентами (2, 3), если есть
call "%~dp0teamcity\_agents.bat"
echo Запуск CI/CD: %CI_SERVICES%%CI_EXTRA%
docker compose up -d %CI_SERVICES%%CI_EXTRA%
echo.
docker compose ps -a %CI_SERVICES% %CI_AGENTS%
echo TeamCity стартует 1-2 минуты после запуска контейнера.
call "%~dp0_links.bat"
pause
