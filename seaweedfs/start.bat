@echo off
chcp 65001 >nul

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)

echo Запуск seaweedfs...
docker compose -f "%~dp0..\docker-compose.yml" up -d seaweedfs
echo.
echo   Filer UI  - http://localhost:8888
echo   Master UI - http://localhost:9333
echo   S3 API    - http://localhost:8333
echo   Ключи: admin / admin123
echo.
pause
