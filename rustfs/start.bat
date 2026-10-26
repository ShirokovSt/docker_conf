@echo off
chcp 65001 >nul

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)
rem сеть devstack_default с подсетью, свободной на этом ПК (один раз создаёт _net.bat)
call "%~dp0..\_net.bat" || (pause & exit /b 1)

echo Запуск rustfs + S3 Manager...
docker compose -f "%~dp0..\docker-compose.yml" up -d rustfs s3manager
echo.
echo   UI  - http://localhost:9003
echo   API - http://localhost:9002
echo   S3 Manager - http://localhost:9006/rustfs/buckets
echo   Ключи: admin / admin123
echo.
pause
