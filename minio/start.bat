@echo off
chcp 65001 >nul

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)

echo Запуск minio + S3 Manager...
docker compose -f "%~dp0..\docker-compose.yml" up -d minio s3manager
echo.
echo   UI  - http://localhost:9001
echo   API - http://localhost:9000
echo   S3 Manager - http://localhost:9006/minio/buckets
echo   Ключи: admin / admin123
echo.
pause
