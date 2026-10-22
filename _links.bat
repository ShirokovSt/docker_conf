@echo off
rem Служебный: печатает ссылки и ключи всех сервисов. Вызывается из start-all.bat, status.bat и menu.bat.
echo.
echo  S3-хранилища
echo  Сервис     UI                         API (endpoint)           Ключи (access / secret)
echo  ---------  -------------------------  -----------------------  ------------------------------
echo  minio      http://localhost:9001      http://localhost:9000    admin / admin123
echo  rustfs     http://localhost:9003      http://localhost:9002    admin / admin123
echo  zenko      -                          http://localhost:9004    admin / admin123
echo  s3proxy    -                          http://localhost:9005    admin / admin123
echo  seaweedfs  http://localhost:8888      http://localhost:8333    admin / admin123
echo             http://localhost:9333 (Master UI)
echo.
echo  Сервисы
echo  Сервис         UI                            Подключение                  Вход
echo  -------------  ----------------------------  ---------------------------  ----------------
echo  kafka          http://localhost:8080         localhost:9092               без логина
echo  elasticsearch  http://localhost:5601         http://localhost:9200        без логина
echo  activemq       http://localhost:8161/admin   tcp://localhost:61616        консоль: admin / admin123
echo.
