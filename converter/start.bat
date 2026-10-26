@echo off
chcp 65001 >nul

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)

echo Запуск converter...
docker compose -f "%~dp0..\docker-compose.yml" up -d converter
echo.
echo   Swagger UI  - http://localhost:8095/swagger-ui.html
echo   Для приложений - http://localhost:8095/lool/convert-to
echo   Проверка    - http://localhost:8095/actuator/health
echo.
echo   LibreOffice стартует 10-20 секунд после запуска контейнера.
echo.
pause
