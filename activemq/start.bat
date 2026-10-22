@echo off
chcp 65001 >nul

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)

echo Запуск activemq...
docker compose -f "%~dp0..\docker-compose.yml" up -d activemq
echo.
echo   Консоль - http://localhost:8161/admin  (admin / admin123)
echo   OpenWire - tcp://localhost:61616, AMQP - amqp://localhost:5672
echo   STOMP - localhost:61613, MQTT - tcp://localhost:1883, WS - ws://localhost:61614
echo.
pause
