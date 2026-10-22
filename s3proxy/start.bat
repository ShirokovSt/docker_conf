@echo off
chcp 65001 >nul

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)

echo Запуск s3proxy + S3 Manager...
docker compose -f "%~dp0..\docker-compose.yml" up -d s3proxy s3manager
echo.
echo   API - http://localhost:9005
echo   S3 Manager - http://localhost:9006/s3proxy/buckets
echo   Ключи: admin / admin123
echo.
pause
