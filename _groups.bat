@echo off
rem Служебный: списки сервисов по группам. Единственное место, где они перечислены.
rem Используется в start-s3 / stop-s3 / start-services / stop-services и menu.bat.
set "S3_SERVICES=minio rustfs zenko s3proxy seaweedfs s3manager"
set "APP_SERVICES=kafka kafka-ui elasticsearch kibana activemq postgres pgadmin spark spark-files prometheus grafana converter"
rem TeamCity (teamcity/docker-compose.yml): сервер, его БД, агент 1, Adminer (БД) и Beszel (графики агентов)
rem и добавленные агенты 2, 3 - те,
rem чьи контейнеры уже созданы (menu.bat, пункт 10 "Агенты CI/CD"). CI_EXTRA - только добавленные:
rem docker compose up / stop без имён сервисов их не трогает, поэтому они передаются явно.
set "CI_EXTRA="
for %%n in (2 3) do docker container inspect teamcity-agent-%%n >nul 2>&1 && call set "CI_EXTRA=%%CI_EXTRA%% teamcity-agent-%%n"
set "CI_SERVICES=teamcity-db teamcity teamcity-agent-1 adminer beszel beszel-agent%CI_EXTRA%"
