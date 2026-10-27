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

echo Запуск mailpit...
docker compose -f "%~dp0..\docker-compose.yml" up -d mailpit
echo.
echo   Веб-интерфейс - http://localhost:8025  (без логина)
echo   SMTP          - localhost:1025 (из контейнеров - mailpit:1025), без TLS, логин любой
echo.
pause
