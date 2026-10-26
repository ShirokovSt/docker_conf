@echo off
chcp 65001 >nul
rem Хранение логов билдов TeamCity.
rem   log-retention.bat        - показать, для скольких последних билдов хранятся логи
rem   log-retention.bat 3      - хранить логи и артефакты 3 последних успешных билдов каждой конфигурации
rem   log-retention.bat now    - запустить очистку сейчас (сама идёт каждую ночь в 3:00)
rem Сервер TeamCity должен быть запущен. Подробно - README.md, раздел "Хранение логов".

set "st="
for /f "delims=" %%s in ('docker container inspect -f "{{.State.Status}}" teamcity 2^>nul') do set "st=%%s"
if not "%st%"=="running" (
    echo [!] Контейнер teamcity не запущен - запустите TeamCity.
    exit /b 1
)

if "%~1"=="" (
    call :show
    exit /b 0
)
if /i "%~1"=="now" (
    docker exec -i teamcity sh -s -- now < "%~dp0log-retention.sh" >nul
    echo Очистка запущена, ход - в TeamCity: Administration - Server Administration - Clean-up.
    exit /b 0
)
docker exec -i -u tcuser teamcity sh -s -- set %~1 < "%~dp0log-retention.sh"
if errorlevel 1 (
    echo [!] Нужно целое число, например: log-retention.bat 3
    exit /b 1
)
call :show
echo Старые логи удалятся ночью в 3:00 или сразу: log-retention.bat now
exit /b 0

:show
set "n="
for /f "delims=" %%v in ('docker exec -i teamcity sh -s -- get ^< "%~dp0log-retention.sh"') do set "n=%%v"
if defined n (
    echo Логи и артефакты хранятся у %n% последних успешных билдов каждой конфигурации.
) else (
    echo Правило хранения логов не задано - логи хранятся без ограничения. Задать: log-retention.bat 3
)
exit /b 0
