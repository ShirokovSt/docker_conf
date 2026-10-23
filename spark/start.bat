@echo off
chcp 65001 >nul

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)

echo Запуск spark spark-files...
docker compose -f "%~dp0..\docker-compose.yml" up -d spark spark-files
echo.
echo   Spark Connect - sc://localhost:15002
echo   Spark UI      - http://localhost:4040
echo   Файлы Spark   - http://localhost:8090  (папка spark\data, в Spark - /data)
echo.
echo   Свои jar      - папка spark\jars (после изменения - перезапуск spark)
echo   Первый запуск - до минуты: скачивается модуль Spark Connect.
echo   Готовность смотрите в logs.bat.
echo.
pause
