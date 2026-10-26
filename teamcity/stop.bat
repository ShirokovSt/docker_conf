@echo off
chcp 65001 >nul

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)

call "%~dp0..\_groups.bat"
echo Остановка TeamCity:%CI_SERVICES%
docker compose -f "%~dp0..\docker-compose.yml" stop %CI_SERVICES%
echo.
docker compose -f "%~dp0..\docker-compose.yml" ps -a %CI_SERVICES%
pause
