@echo off
rem Служебный: списки сервисов по группам. Единственное место, где они перечислены. Docker не вызывает.
rem Используется в start-s3 / stop-s3 / start-services / stop-services, start-cicd / stop-cicd и menu.bat.
set "S3_SERVICES=minio rustfs zenko s3proxy seaweedfs s3manager"
set "APP_SERVICES=kafka kafka-ui elasticsearch kibana activemq postgres pgadmin spark spark-files prometheus grafana converter"
rem TeamCity (teamcity/docker-compose.yml): сервер, его БД и агент 1.
rem CI_AGENTS - агенты 2, 3: добавляются из menu.bat (пункт 10 "Агенты CI/CD"). Для остановки и статуса их можно
rem называть всегда (несозданные просто пропускаются), для запуска - только созданные: их находит teamcity\_agents.bat.
set "CI_SERVICES=teamcity-db teamcity teamcity-agent-1"
set "CI_AGENTS=teamcity-agent-2 teamcity-agent-3"
