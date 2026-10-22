@echo off
chcp 65001 >nul

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)

echo Запуск zenko...
docker compose -f "%~dp0..\docker-compose.yml" up -d zenko
echo.
echo   API - http://localhost:9004
echo   Ключи: admin / admin123
echo.
pause
