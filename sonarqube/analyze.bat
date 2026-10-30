@echo off
chcp 65001 >nul
setlocal
set "DOCKER_CLI_HINTS=false"
rem Анализ Maven- или Gradle-проекта в SonarQube из командной строки. То же самое - на странице http://localhost:9011.
rem   analyze.bat [папка проекта] [notests] [JDK] [ключ проекта]
rem   analyze.bat C:\work\svc            - JDK 21, с тестами
rem   analyze.bat C:\work\svc 8          - сборка и тесты на JDK 8
rem   analyze.bat C:\work\svc notests 17 - JDK 17, без тестов
rem   analyze.bat C:\work\svc 17 my-key  - результат в проект с ключом my-key (по умолчанию - ключ из сборки)
rem Без аргументов открывает окно выбора папки Windows, затем спрашивает тесты, JDK и ключ.
rem Сам анализ делает sonarqube-ui (sonarqube\ui\analyze.sh): сборка в контейнере, на этом ПК ничего ставить не нужно.
rem После анализа открывает отчёт в браузере.

docker info >nul 2>&1
if errorlevel 1 (
    echo [!] Docker не отвечает. Запустите Docker Desktop и повторите.
    pause
    exit /b 1
)
call "%~dp0..\_net.bat" || (pause & exit /b 1)

set "src=%~1"
if defined src goto have_src
echo Выберите папку проекта в открывшемся окне...
for /f "usebackq delims=" %%p in (`powershell -NoProfile -STA -Command "[Console]::OutputEncoding = [Text.Encoding]::UTF8; Add-Type -AssemblyName System.Windows.Forms; $d = New-Object System.Windows.Forms.FolderBrowserDialog; $d.Description = 'Папка Maven- или Gradle-проекта'; $d.ShowNewFolderButton = $false; if ($d.ShowDialog() -eq 'OK') { $d.SelectedPath }"`) do set "src=%%p"
:have_src
if not defined src (
    echo Папка не выбрана.
    pause
    exit /b 1
)
rem кавычки из ввода (путь, скопированный "как путь") и завершающий \
set "src=%src:"=%"
for %%i in ("%src%") do set "src=%%~fi"
if "%src:~-1%"=="\" set "src=%src:~0,-1%"
if not exist "%src%\" (
    echo [!] Папка не найдена: %src%
    pause
    exit /b 1
)

set "opts=%2 %3 %4"
if "%~1"=="" (
    set "opts="
    set "yn=" & set "jdk=" & set "key="
    set /p "yn=Запускать тесты? Нужны для покрытия (Enter - да, n - нет): "
    set /p "jdk=JDK для сборки и тестов (Enter - 21; 17, 11, 8 или другая версия): "
    set /p "key=Ключ проекта в SonarQube (Enter - из сборки): "
)
if "%~1"=="" (
    if /i "%yn%"=="n" set "opts=notests"
)
if "%~1"=="" set "opts=%opts% %jdk% %key%"

rem C:\work\app -> /host/c/work/app: так диски ПК видит sonarqube-ui
set "drive=%src:~0,1%"
for %%l in (a b c d e f g h i j k l m n o p q r s t u v w x y z) do if /i "%drive%"=="%%l" set "drive=%%l"
set "rest=%src:~2%"
set "hostpath=/host/%drive%%rest:\=/%"

rem старая ссылка на отчёт не должна открыться, если анализ не прошёл
del /q "%src%\target\sonar\report-task.txt" "%src%\build\sonar\report-task.txt" "%src%\.scannerwork\report-task.txt" 2>nul

docker compose -f "%~dp0..\docker-compose.yml" up -d sonarqube-ui >nul || (pause & exit /b 1)
docker exec -it sonarqube-ui sh /app/analyze.sh "%hostpath%" %opts%
if errorlevel 1 (
    echo.
    echo [!] Анализ не прошёл - причина выше.
    pause
    exit /b 1
)

set "url="
for %%f in ("%src%\target\sonar\report-task.txt" "%src%\build\sonar\report-task.txt" "%src%\.scannerwork\report-task.txt") do (
    if exist %%f for /f "usebackq tokens=1,* delims==" %%a in (%%f) do if "%%a"=="dashboardUrl" set "url=%%b"
)
if defined url start "" "%url%"
pause
