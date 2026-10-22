# Zenko CloudServer

| | |
|---|---|
| Веб-интерфейс (S3 Manager) | http://localhost:9006/zenko/buckets |
| S3 API | http://localhost:9004 |
| Access key | `admin` |
| Secret key | `admin123` |
| Контейнер / сервис | `zenko` |
| Данные | `zenko_cloudserver/data` (объекты), `zenko_cloudserver/metadata` (метаданные) |

Запуск: `start.bat` (вместе с общим S3 Manager), остановка: `stop.bat`, логи: `logs.bat` (в этой папке). Всё сразу — `start-all.bat` в корне.

Веб-интерфейс — общий для всех хранилищ [S3 Manager](../README.md#s3-manager): бакеты (создать, удалить), загрузка файлов и папок, скачивание (в том числе ZIP), удаление, временные ссылки. Без логина.

Папки `data` и `metadata` работают только вместе: не удаляйте и не переносите одну без другой.

Zenko принимает запросы только с разрешёнными именами хоста (заголовок `Host`): по умолчанию `localhost`, `127.0.0.1` и т.п. Поэтому в compose задано `ENDPOINT: zenko`: S3 Manager обращается к нему по имени `zenko`, и без этой переменной получает «Connection error». Если к zenko будет обращаться ещё что-то по другому имени, допишите его через запятую: `ENDPOINT: zenko,other-name`.

## AWS CLI

Профиль `zenko` создаётся `aws-profiles.bat` в корне.

```bat
aws --version
aws --profile zenko s3 ls
aws --profile zenko s3 mb s3://my-first-bucket
aws --profile zenko s3 ls s3://my-first-bucket/
aws --profile zenko s3 ls s3://my-first-bucket/ --recursive --human-readable --summarize
aws --profile zenko s3 cp C:\temp\file.txt s3://my-first-bucket/
aws --profile zenko s3 cp s3://my-first-bucket/file.txt C:\temp\
aws --profile zenko s3 sync C:\temp\folder s3://my-first-bucket/folder/
aws --profile zenko s3 rm s3://my-first-bucket/file.txt
aws --profile zenko s3 rb s3://my-first-bucket --force
aws --profile zenko s3 presign s3://my-first-bucket/file.txt --expires-in 3600
```

Без профиля (как было раньше — перезаписывает default-профиль):

```bat
aws configure set aws_access_key_id admin
aws configure set aws_secret_access_key admin123
aws configure set default.region us-east-1
aws --endpoint-url=http://localhost:9004 s3 ls
```

## Запасной вариант: docker run

Выполнять в cmd из папки `docker_conf` (`%cd%` — текущая папка).

```bat
docker run -d ^
  --name zenko ^
  -p 9004:8000 ^
  -v "%cd%\zenko_cloudserver\data:/data" ^
  -v "%cd%\zenko_cloudserver\metadata:/metadata" ^
  -e SCALITY_ACCESS_KEY_ID=admin ^
  -e SCALITY_SECRET_ACCESS_KEY=admin123 ^
  -e S3DATAPATH=/data ^
  -e S3METADATAPATH=/metadata ^
  -e REMOTE_MANAGEMENT_DISABLE=1 ^
  -e ENDPOINT=zenko ^
  zenko/cloudserver
```
