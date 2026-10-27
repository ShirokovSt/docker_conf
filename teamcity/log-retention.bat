@echo off
chcp 65001 >nul
rem Хранение логов билдов TeamCity.
rem   log-retention.bat        - показать, для скольких последних билдов хранятся логи
rem   log-retention.bat 3      - хранить логи и артефакты 3 последних билдов (любого статуса) каждой конфигурации
rem   log-retention.bat now    - запустить очистку сейчас (сама идёт после каждого билда и ночью в 3:00)
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
echo Записываю правило - до минуты: сервер должен перечитать настройки...
docker exec -i -u tcuser teamcity sh -s -- set %~1 < "%~dp0log-retention.sh"
if errorlevel 1 (
    echo [!] Не получилось - нужно целое число больше 0, например: log-retention.bat 3
    exit /b 1
)
call :show
echo Лишние логи удалятся после следующего билда или сразу: log-retention.bat now
exit /b 0

:show
set "n="
for /f "delims=" %%v in ('docker exec -i teamcity sh -s -- get ^< "%~dp0log-retention.sh"') do set "n=%%v"
if defined n (
    echo Логи и артефакты хранятся у %n% последних билдов каждой конфигурации, история - у всех.
) else (
    echo Правило хранения логов не задано - логи хранятся без ограничения. Задать: log-retention.bat 3
)
exit /b 0
