#!/bin/sh
# Запуск sonarqube-ui: в фоне - настройка SonarQube (setup.sh), затем страница анализа (server.js).
sh /app/setup.sh &
exec node /app/server.js
