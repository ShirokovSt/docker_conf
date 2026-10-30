#!/bin/sh
# Сервис sonarqube-dbinit (docker-compose.yml): создаёт базу sonarqube в общем PostgreSQL, если её нет, и завершается.
# SonarQube ждёт его завершения (depends_on: service_completed_successfully). Подключение - PGHOST/PGUSER/PGPASSWORD.

until pg_isready -q; do sleep 1; done

if psql -tAc "SELECT 1 FROM pg_database WHERE datname = 'sonarqube'" | grep -q 1; then
  echo "database sonarqube: ok"
else
  psql -c "CREATE DATABASE sonarqube" && echo "database sonarqube: created"
fi
