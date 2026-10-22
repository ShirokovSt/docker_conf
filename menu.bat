@echo off
chcp 65001 >nul
cd /d "%~dp0"
call "%~dp0_groups.bat"

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)

:menu
cls
echo ===================== Локальные сервисы =====================
echo.
echo   1. Запустить ВСЁ
echo   2. Остановить ВСЁ
echo   3. Статус
echo.
echo   4. Запустить S3-хранилища
echo   5. Остановить S3-хранилища
echo   6. Запустить сервисы - Kafka, Elasticsearch, ActiveMQ
echo   7. Остановить сервисы
echo.
echo   8. Запустить один
echo   9. Остановить один
echo  10. Перезапустить один
echo  11. Логи одного - последние 200 строк
echo.
echo  12. Открыть веб-интерфейс
echo  13. Ссылки и ключи
echo.
echo   0. Выход
echo.
set "choice="
set /p "choice=Выберите пункт: "

if "%choice%"=="1"  goto start_all
if "%choice%"=="2"  goto stop_all
if "%choice%"=="3"  goto status
if "%choice%"=="4"  set "group=%S3_SERVICES%"  & set "action=start" & goto group
if "%choice%"=="5"  set "group=%S3_SERVICES%"  & set "action=stop"  & goto group
if "%choice%"=="6"  set "group=%APP_SERVICES%" & set "action=start" & goto group
if "%choice%"=="7"  set "group=%APP_SERVICES%" & set "action=stop"  & goto group
if "%choice%"=="8"  set "action=start"   & goto pick
if "%choice%"=="9"  set "action=stop"    & goto pick
if "%choice%"=="10" set "action=restart" & goto pick
if "%choice%"=="11" set "action=logs"    & goto pick
if "%choice%"=="12" goto open_ui
if "%choice%"=="13" goto links
if "%choice%"=="0"  exit /b 0
goto menu

:start_all
docker compose up -d
docker compose ps
pause
goto menu

:stop_all
docker compose stop
pause
goto menu

:status
docker compose ps -a
pause
goto menu

:links
call "%~dp0_links.bat"
pause
goto menu

:group
if "%action%"=="start" docker compose up -d %group%
if "%action%"=="stop"  docker compose stop %group%
docker compose ps -a %group%
pause
goto menu

:open_ui
echo.
echo   1. minio   2. rustfs   3. seaweedfs - Filer и Master
echo   4. Kafka UI   5. Kibana   6. ActiveMQ
echo   7. все сразу
echo   Enter - назад
echo.
set "n="
set /p "n=Что открыть: "
if "%n%"=="1" start "" http://localhost:9001
if "%n%"=="2" start "" http://localhost:9003
if "%n%"=="3" start "" http://localhost:8888 & start "" http://localhost:9333
if "%n%"=="4" start "" http://localhost:8080
if "%n%"=="5" start "" http://localhost:5601
if "%n%"=="6" start "" http://localhost:8161/admin
if "%n%"=="7" goto open_all
goto menu

:open_all
for %%u in (9001 9003 8888 9333 8080 5601) do start "" http://localhost:%%u
start "" http://localhost:8161/admin
goto menu

:pick
echo.
echo   S3:       1. minio   2. rustfs   3. zenko   4. s3proxy   5. seaweedfs
echo   Сервисы:  6. kafka + kafka-ui   7. elasticsearch + kibana   8. activemq
echo   Enter - назад
echo.
set "svc="
set "n="
set /p "n=Сервис: "
if "%n%"=="1" set "svc=minio"
if "%n%"=="2" set "svc=rustfs"
if "%n%"=="3" set "svc=zenko"
if "%n%"=="4" set "svc=s3proxy"
if "%n%"=="5" set "svc=seaweedfs"
if "%n%"=="6" set "svc=kafka kafka-ui"
if "%n%"=="7" set "svc=elasticsearch kibana"
if "%n%"=="8" set "svc=activemq"
if not defined svc goto menu

if "%action%"=="start"   docker compose up -d %svc%
if "%action%"=="stop"    docker compose stop %svc%
if "%action%"=="restart" docker compose restart %svc%
if "%action%"=="logs"    docker compose logs --tail 200 %svc%
pause
goto menu
