@echo off
chcp 65001 >nul

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)

echo Запуск postgres pgadmin...
docker compose -f "%~dp0..\docker-compose.yml" up -d postgres pgadmin
echo.
echo   pgAdmin    - http://localhost:5050  (без логина, сервер уже добавлен)
echo   PostgreSQL - localhost:5434, postgres / admin123
echo   jdbc:postgresql://localhost:5434/postgres
echo.
pause
