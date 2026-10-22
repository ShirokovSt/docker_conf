@echo off
chcp 65001 >nul

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)

echo Запуск rustfs...
docker compose -f "%~dp0..\docker-compose.yml" up -d rustfs
echo.
echo   UI  - http://localhost:9003
echo   API - http://localhost:9002
echo   Ключи: admin / admin123
echo.
pause
