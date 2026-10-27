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

echo Запуск prometheus grafana...
docker compose -f "%~dp0..\docker-compose.yml" up -d prometheus grafana
echo.
echo   Grafana    - http://localhost:3000  (без логина, дашборд Spring Boot)
echo                http://localhost:3000/d/teamcity  (дашборд TeamCity, если он запущен)
echo   Prometheus - http://localhost:9090  (цели: http://localhost:9090/targets)
echo.
echo   Spring-приложение запускайте на порту 8199.
echo   Другой порт - допишите его в monitoring\prometheus\targets.yml (перезапуск не нужен).
echo.
pause
