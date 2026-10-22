# S3Proxy

| | |
|---|---|
| Веб-интерфейс (S3 Manager) | http://localhost:9006/s3proxy/buckets |
| S3 API | http://localhost:9005 |
| Access key | `admin` |
| Secret key | `admin123` |
| Контейнер / сервис | `s3proxy` |
| Данные | `s3proxy/data` — бакет = обычная папка, объект = обычный файл |

Запуск: `start.bat` (вместе с общим S3 Manager), остановка: `stop.bat`, логи: `logs.bat` (в этой папке). Всё сразу — `start-all.bat` в корне.

Веб-интерфейс — общий для всех хранилищ [S3 Manager](../README.md#s3-manager): бакеты (создать, удалить), загрузка файлов и папок, скачивание (в том числе ZIP), удаление, временные ссылки. Без логина.

Порт — **9005** (в старой инструкции по ошибке был указан 9004, это порт zenko).

Содержимое бакетов можно смотреть прямо в проводнике: `s3proxy\data\<бакет>\`.

## AWS CLI

Профиль `s3proxy` создаётся `aws-profiles.bat` в корне.

```bat
aws --version
aws --profile s3proxy s3 ls
aws --profile s3proxy s3 mb s3://my-first-bucket
aws --profile s3proxy s3 ls s3://my-first-bucket/
aws --profile s3proxy s3 ls s3://my-first-bucket/ --recursive --human-readable --summarize
aws --profile s3proxy s3 cp C:\temp\file.txt s3://my-first-bucket/
aws --profile s3proxy s3 cp s3://my-first-bucket/file.txt C:\temp\
aws --profile s3proxy s3 sync C:\temp\folder s3://my-first-bucket/folder/
aws --profile s3proxy s3 rm s3://my-first-bucket/file.txt
aws --profile s3proxy s3 rb s3://my-first-bucket --force
aws --profile s3proxy s3 presign s3://my-first-bucket/file.txt --expires-in 3600
```

Без профиля (перезаписывает default-профиль):

```bat
aws configure set aws_access_key_id admin
aws configure set aws_secret_access_key admin123
aws configure set default.region us-east-1
aws --endpoint-url=http://localhost:9005 s3 ls
```

## Запасной вариант: docker run

Выполнять в cmd из папки `docker_conf` (`%cd%` — текущая папка).

```bat
docker run -d ^
  --name s3proxy ^
  -p 9005:80 ^
  -e S3PROXY_IDENTITY=admin ^
  -e S3PROXY_CREDENTIAL=admin123 ^
  -v "%cd%\s3proxy\data:/data" ^
  andrewgaul/s3proxy
```
