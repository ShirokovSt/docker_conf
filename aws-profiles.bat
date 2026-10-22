@echo off
chcp 65001 >nul
rem Один раз создаёт профили AWS CLI под каждое хранилище (ключи + endpoint).
rem После этого: aws --profile minio s3 ls   (без --endpoint-url и без перезаписи default-профиля)
rem endpoint_url в профиле поддерживается в AWS CLI v2.13+.

where aws >nul 2>&1
if errorlevel 1 (
    echo [!] AWS CLI не найден. Установите: https://aws.amazon.com/cli/
    pause
    exit /b 1
)

aws --version
echo.
echo Создаю профили AWS CLI...
call :profile minio     admin admin123 http://localhost:9000
call :profile rustfs    admin admin123 http://localhost:9002
call :profile zenko     admin admin123 http://localhost:9004
call :profile s3proxy   admin admin123 http://localhost:9005
call :profile seaweedfs admin admin123 http://localhost:8333
echo.
echo Готово. Пример: aws --profile minio s3 ls
pause
exit /b 0

:profile
aws configure set aws_access_key_id     %2 --profile %1
aws configure set aws_secret_access_key %3 --profile %1
aws configure set region                us-east-1 --profile %1
aws configure set endpoint_url          %4 --profile %1
echo   [ok] %1  -^>  %4
exit /b 0
