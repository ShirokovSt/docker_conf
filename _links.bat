@echo off
rem Служебный: печатает ссылки и ключи всех сервисов. Вызывается из start-all.bat, status.bat и menu.bat.
echo.
echo  S3-хранилища
echo  Сервис     UI                                      API (endpoint)           Ключи (access / secret)
echo  ---------  --------------------------------------  -----------------------  -----------------------
echo  minio      http://localhost:9001                   http://localhost:9000    admin / admin123
echo  rustfs     http://localhost:9003                   http://localhost:9002    admin / admin123
echo  zenko      http://localhost:9006/zenko/buckets     http://localhost:9004    admin / admin123
echo  s3proxy    http://localhost:9006/s3proxy/buckets   http://localhost:9005    admin / admin123
echo  seaweedfs  http://localhost:8888                   http://localhost:8333    admin / admin123
echo             http://localhost:9333 (Master UI)
echo.
echo  S3 Manager - общий UI для всех хранилищ: http://localhost:9006/^<хранилище^>/buckets
echo.
echo  Сервисы
echo  Сервис         UI                                     Подключение                            Вход
echo  -------------  -------------------------------------  -------------------------------------  ----------------
echo  kafka          http://localhost:8080                  localhost:9092                         без логина
echo  elasticsearch  http://localhost:5601                  http://localhost:9200                  без логина
echo  activemq       http://localhost:8161/admin            tcp://localhost:61616                  консоль: admin / admin123
echo  postgres       http://localhost:5050                  localhost:5434                         postgres / admin123
echo  spark          http://localhost:4040                  sc://localhost:15002                   без логина
echo  файлы Spark    http://localhost:8090                  папка spark\data = /data               без логина
echo  grafana        http://localhost:3000                  -                                      без логина
echo  prometheus     http://localhost:9090/targets          читает Spring на :8199                 без логина
echo  converter      http://localhost:8095/swagger-ui.html  http://localhost:8095/lool/convert-to  без логина
echo.
echo  CI/CD
echo  Сервис         UI                                     Подключение                            Вход
echo  -------------  -------------------------------------  -------------------------------------  ----------------
echo  teamcity       http://localhost:8111                  агенты, Remote Run из IDEA             admin / admin123
echo  база TeamCity  http://localhost:5050                  pgAdmin, сервер teamcity-db            без логина
echo  метрики        http://localhost:3000                  Grafana, дашборд TeamCity              без логина
echo.
