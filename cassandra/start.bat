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

echo Запуск cassandra cassandra-ui...
echo Cassandra стартует около минуты; интерфейс поднимется, когда она будет готова.
echo При первом запуске ещё собирается образ интерфейса.
docker compose -f "%~dp0..\docker-compose.yml" up -d cassandra cassandra-ui
echo.
echo   Интерфейс - http://localhost:8097  (без логина): keyspace'ы, таблицы, файлы, CQL-консоль
echo   CQL       - localhost:9042, датацентр datacenter1 (из контейнеров - cassandra:9042)
echo   Консоль   - cqlsh.bat в этой папке
echo.
pause
