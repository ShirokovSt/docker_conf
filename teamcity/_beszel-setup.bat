@echo off
chcp 65001 >nul
rem Служебный: подключает агента Beszel (графики контейнеров) к hub - один раз, повторный запуск ничего не меняет.
rem Вызывается из start.bat и menu.bat после запуска контейнеров. Что делает - в _beszel-setup.ps1.
powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0_beszel-setup.ps1" <nul
exit /b %errorlevel%
