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

rem sonarqube-ui поднимает и SonarQube (с ним - postgres и одноразовый sonarqube-dbinit, который создаёт базу)
rem и настраивает его: пароль admin123, токен для анализа
echo Запуск sonarqube и страницы анализа...
docker compose -f "%~dp0..\docker-compose.yml" up -d sonarqube-ui
echo.
echo   SonarQube        - http://localhost:9010  (admin / admin123), готов через 1-3 минуты
echo   Анализ проекта   - http://localhost:9011  или sonarqube\analyze.bat ^<папка проекта^>
echo.
pause
