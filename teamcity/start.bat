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
call "%~dp0_tz.bat"
echo Запуск TeamCity:%CI_SERVICES%
docker compose -f "%~dp0..\docker-compose.yml" up -d %CI_SERVICES%
rem агент Beszel (графики контейнеров) подключается к hub один раз
call "%~dp0_beszel-setup.bat"
echo.
docker compose -f "%~dp0..\docker-compose.yml" ps -a %CI_SERVICES%
echo.
echo   TeamCity - http://localhost:8111  (готов через 1-2 минуты, ход запуска - logs.bat)
echo   Агенты   - Agent (devstack)-N: JDK 8/11/17/21, Maven 3.6.3/3.9, Docker
echo   Графики агентов - http://localhost:8091 (Beszel, admin@example.com / admin123)
echo   База TeamCity   - http://localhost:8082/?pgsql=teamcity-db (Adminer, teamcity / admin123, база teamcity)
echo   Хранение логов билдов - log-retention.bat (сейчас и ночью в 3:00 чистится всё, кроме последних билдов)
echo              добавить агента - menu.bat, пункт 10 "Агенты CI/CD"
echo   Папки этого ПК в сборках - /host, например D:\work\app = /host/d/work/app
echo   Первый запуск - мастер настройки, см. teamcity\README.md
echo.
pause
