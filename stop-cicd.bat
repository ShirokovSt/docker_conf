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

echo Остановка CI/CD: %CI_SERVICES% %CI_AGENTS%
docker compose stop %CI_SERVICES% %CI_AGENTS%
echo.
docker compose ps -a %CI_SERVICES% %CI_AGENTS%
pause
