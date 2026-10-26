@echo off
rem Служебный: сеть Docker devstack_default с подсетью, свободной на этом ПК - не пересекается с VPN, WSL,
rem другими подключёнными сетями и сетями Docker (иначе контейнеры не достанут до серверов в этих сетях).
rem Подбирается и создаётся один раз (_net.ps1), дальше - мгновенная проверка, что сеть есть.
rem Вызывается из start-all, start-s3, start-services, menu и <папка>\start.bat перед docker compose up.
docker network inspect devstack_default >nul 2>&1 && exit /b 0
powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0_net.ps1" <nul
exit /b %errorlevel%
