@echo off
rem Служебный: часовой пояс этого ПК в формате IANA (например Europe/Moscow) - в переменную HOST_TZ.
rem Агенты TeamCity получают его как TZ (teamcity\docker-compose.yml): время в сборках и тестах - как на этом ПК.
rem Вызывается из start-all.bat, start-cicd.bat, menu.bat и teamcity\start.bat перед docker compose up.
rem Если HOST_TZ уже задан в окружении - не трогает. Не получилось определить - остаётся пусто, compose возьмёт
rem HOST_TZ из .env или UTC.
if defined HOST_TZ exit /b 0
for /f "usebackq delims=" %%z in (`powershell -NoProfile -NonInteractive -Command "$null = [Windows.Globalization.Calendar,Windows.Globalization,ContentType=WindowsRuntime]; (New-Object Windows.Globalization.Calendar).GetTimeZone()" ^<nul 2^>nul`) do set "HOST_TZ=%%z"
exit /b 0
