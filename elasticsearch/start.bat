@echo off
chcp 65001 >nul

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)

echo Запуск elasticsearch kibana...
docker compose -f "%~dp0..\docker-compose.yml" up -d elasticsearch kibana
echo.
echo   Kibana - http://localhost:5601  (стартует 1-2 минуты)
echo   API    - http://localhost:9200
echo   Без логина и пароля
echo.
pause
