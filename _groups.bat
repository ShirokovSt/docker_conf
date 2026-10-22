@echo off
rem Служебный: списки сервисов по группам. Единственное место, где они перечислены.
rem Используется в start-s3 / stop-s3 / start-services / stop-services и menu.bat.
set "S3_SERVICES=minio rustfs zenko s3proxy seaweedfs"
set "APP_SERVICES=kafka kafka-ui elasticsearch kibana activemq"
