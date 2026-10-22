@echo off
chcp 65001 >nul
rem Бэкап всех БД, ролей и прав PostgreSQL в postgres\backup\all_<дата_время>.sql (pg_dumpall).
rem Контейнер postgres должен быть запущен. Восстановление - см. postgres\README.md.

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "ts=%%i"
set "file=all_%ts%.sql"

echo Бэкап в postgres\backup\%file% ...
docker exec postgres pg_dumpall -U postgres -f /backup/%file%
if errorlevel 1 (
    echo [!] Не получилось. Контейнер postgres запущен? Запуск: postgres\start.bat
    pause
    exit /b 1
)
echo Готово: %~dp0backup\%file%
pause
