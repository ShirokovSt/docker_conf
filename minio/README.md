# MinIO

| | |
|---|---|
| Веб-интерфейс | http://localhost:9001 |
| S3 API | http://localhost:9000 |
| Access key | `admin` |
| Secret key | `admin123` |
| Контейнер / сервис | `minio` |
| Данные | `minio/data` (каждый бакет — подпапка) |

Запуск: `start.bat`, остановка: `stop.bat`, логи: `logs.bat` (в этой папке). Всё сразу — `start-all.bat` в корне.

## AWS CLI

Профиль `minio` создаётся `aws-profiles.bat` в корне.

```bat
aws --profile minio s3 ls
aws --profile minio s3 mb s3://my-bucket
aws --profile minio s3 ls s3://my-bucket/ --recursive --human-readable --summarize
aws --profile minio s3 cp C:\temp\file.txt s3://my-bucket/
aws --profile minio s3 cp s3://my-bucket/file.txt C:\temp\
aws --profile minio s3 sync C:\temp\folder s3://my-bucket/folder/
aws --profile minio s3 rm s3://my-bucket/file.txt
aws --profile minio s3 rb s3://my-bucket --force
aws --profile minio s3 presign s3://my-bucket/file.txt --expires-in 3600
```

Без профиля: `aws --endpoint-url http://localhost:9000 s3 ls` (ключи из таблицы через `aws configure`).

## MinIO Client (mc) внутри контейнера

Один раз после создания контейнера задать alias:

```bat
docker exec minio mc alias set local http://localhost:9000 admin admin123
```

Дальше:

| Команда | Что делает |
|---|---|
| `docker exec minio mc ls local` | список бакетов |
| `docker exec minio mc mb local/my-bucket` | создать бакет |
| `docker exec minio mc ls --recursive local/my-bucket` | содержимое бакета |
| `docker exec minio mc du local/my-bucket` | размер бакета |
| `docker exec minio mc rb --force local/my-bucket` | удалить бакет с содержимым |
| `docker exec minio mc admin info local` | состояние сервера |
| `docker exec minio mc version enable local/my-bucket` | включить версионирование |

Если в образе нет `mc`, его можно запустить отдельным контейнером в той же сети:
`docker run --rm -it --network devstack_default --entrypoint sh minio/mc`, внутри — `mc alias set local http://minio:9000 <key> <secret>`.

## Запасной вариант: docker run

Выполнять в cmd из папки `docker_conf` (`%cd%` — текущая папка).

```bat
docker run -d ^
  --name minio ^
  -p 9000:9000 -p 9001:9001 ^
  -v "%cd%\minio\data:/data" ^
  -e "MINIO_ROOT_USER=admin" ^
  -e "MINIO_ROOT_PASSWORD=admin123" ^
  minio/minio server /data --console-address ":9001"
```
