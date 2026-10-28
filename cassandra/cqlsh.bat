@echo off
chcp 65001 >nul
rem Консоль cqlsh внутри контейнера cassandra. Выход - exit.

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)

docker container inspect -f "{{.State.Running}}" cassandra 2>nul | findstr /x true >nul
if errorlevel 1 (
    echo [!] Контейнер cassandra не запущен - запустите start.bat.
    pause
    exit /b 1
)
docker exec -it cassandra cqlsh
