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

rem postgres остаётся: он общий, останавливается со своей группой (stop-services.bat)
echo Остановка анализа кода: %CODE_SERVICES%
docker compose stop %CODE_SERVICES%
echo.
docker compose ps -a %CODE_SERVICES%
pause
