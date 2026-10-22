# RustFS

| | |
|---|---|
| Веб-интерфейс | http://localhost:9003 |
| S3 API | http://localhost:9002 |
| Access key | `admin` |
| Secret key | `admin123` |
| Контейнер / сервис | `rustfs` |
| Данные | `rustfs/data` |

Запуск: `start.bat`, остановка: `stop.bat`, логи: `logs.bat` (в этой папке). Всё сразу — `start-all.bat` в корне.

Бакеты удобно смотреть и создавать в веб-интерфейсе (логин — ключи из таблицы).

## AWS CLI

Профиль `rustfs` создаётся `aws-profiles.bat` в корне.

```bat
aws --profile rustfs s3 ls
aws --profile rustfs s3 mb s3://my-bucket
aws --profile rustfs s3 ls s3://my-bucket/ --recursive --human-readable --summarize
aws --profile rustfs s3 cp C:\temp\file.txt s3://my-bucket/
aws --profile rustfs s3 cp s3://my-bucket/file.txt C:\temp\
aws --profile rustfs s3 sync C:\temp\folder s3://my-bucket/folder/
aws --profile rustfs s3 rm s3://my-bucket/file.txt
aws --profile rustfs s3 rb s3://my-bucket --force
aws --profile rustfs s3 presign s3://my-bucket/file.txt --expires-in 3600
```

Без профиля: `aws --endpoint-url http://localhost:9002 s3 ls` (ключи из таблицы через `aws configure`).

## Запасной вариант: docker run

Выполнять в cmd из папки `docker_conf` (`%cd%` — текущая папка).

```bat
docker run -d ^
  --name rustfs ^
  -p 9002:9002 -p 9003:9003 ^
  -v "%cd%\rustfs\data:/data" ^
  -e RUSTFS_ACCESS_KEY=admin ^
  -e RUSTFS_SECRET_KEY=admin123 ^
  -e RUSTFS_CONSOLE_ENABLE=true ^
  rustfs/rustfs:latest ^
  --address ":9002" ^
  --console-address ":9003" ^
  --console-enable ^
  --access-key admin ^
  --secret-key admin123 ^
  /data
```
