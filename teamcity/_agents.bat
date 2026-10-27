@echo off
rem Служебный: CI_EXTRA - добавленные агенты TeamCity (2, 3), чьи контейнеры уже созданы (menu.bat, пункт 10).
rem docker compose up без имён их не трогает (профили agent-2 / agent-3), поэтому при запуске они передаются явно.
rem Вызывается только при запуске TeamCity: start-all, start-cicd, teamcity\start.bat, menu.bat.
set "CI_EXTRA="
for %%n in (2 3) do docker container inspect teamcity-agent-%%n >nul 2>&1 && call set "CI_EXTRA=%%CI_EXTRA%% teamcity-agent-%%n"
exit /b 0
