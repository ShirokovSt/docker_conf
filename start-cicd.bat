@echo off
chcp 65001 >nul
cd /d "%~dp0"
call "%~dp0_groups.bat"
call "%~dp0_tz.bat"

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)
rem сеть devstack_default с подсетью, свободной на этом ПК (один раз создаёт _net.bat)
call "%~dp0_net.bat" || (pause & exit /b 1)

echo Запуск CI/CD: %CI_SERVICES%
docker compose up -d %CI_SERVICES%
rem агент Beszel (графики контейнеров) подключается к hub один раз
call "%~dp0teamcity\_beszel-setup.bat"
echo.
docker compose ps -a %CI_SERVICES%
echo TeamCity стартует 1-2 минуты после запуска контейнера.
call "%~dp0_links.bat"
pause
