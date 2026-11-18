@echo off
chcp 65001 >nul
cd /d "%~dp0"
call "%~dp0_groups.bat"

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)
rem сеть devstack_default с подсетью, свободной на этом ПК (один раз создаёт _net.bat)
call "%~dp0_net.bat" || (pause & exit /b 1)

rem вместе с ними compose поднимает postgres (база sonarqube) и одноразовый sonarqube-dbinit
echo Запуск анализа кода: %CODE_SERVICES%
docker compose up -d %CODE_SERVICES%
echo.
docker compose ps -a %CODE_SERVICES% postgres
echo SonarQube стартует 1-3 минуты после запуска контейнера.
echo Анализ проекта - страница http://localhost:9011, sonarqube\analyze.bat или menu.bat.
call "%~dp0_links.bat"
pause
