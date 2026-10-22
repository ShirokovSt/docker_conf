# SeaweedFS

| | |
|---|---|
| Filer UI (файлы и бакеты) | http://localhost:8888 — бакеты в http://localhost:8888/buckets/ |
| Master UI (тома, кластер) | http://localhost:9333 |
| Веб-интерфейс (S3 Manager) | http://localhost:9006/seaweedfs/buckets |
| S3 API | http://localhost:8333 |
| Access key | `admin` |
| Secret key | `admin123` |
| Контейнер / сервис | `seaweedfs` |
| Данные | `seaweedfs/data` (файлы томов `*.dat/*.idx`, напрямую не читаются) |

Запуск: `start.bat` (вместе с общим S3 Manager), остановка: `stop.bat`, логи: `logs.bat` (в этой папке). Всё сразу — `start-all.bat` в корне.

## AWS CLI

Профиль `seaweedfs` создаётся `aws-profiles.bat` в корне.

```bat
aws --profile seaweedfs s3 ls
aws --profile seaweedfs s3 mb s3://my-bucket
aws --profile seaweedfs s3 ls s3://my-bucket/ --recursive --human-readable --summarize
aws --profile seaweedfs s3 cp C:\temp\file.txt s3://my-bucket/
aws --profile seaweedfs s3 cp s3://my-bucket/file.txt C:\temp\
aws --profile seaweedfs s3 sync C:\temp\folder s3://my-bucket/folder/
aws --profile seaweedfs s3 rm s3://my-bucket/file.txt
aws --profile seaweedfs s3 rb s3://my-bucket --force
aws --profile seaweedfs s3 presign s3://my-bucket/file.txt --expires-in 3600
```

Без профиля: `aws --endpoint-url http://localhost:8333 s3 ls` (ключи из таблицы через `aws configure`).

## weed shell (встроенная консоль)

Интерактивно:

```bat
docker exec -it seaweedfs weed shell
```

Команды внутри (`help` — полный список, `exit` — выход):

| Команда | Что делает |
|---|---|
| `s3.bucket.list` | список бакетов |
| `s3.bucket.create -name my-bucket` | создать бакет |
| `s3.bucket.delete -name my-bucket` | удалить бакет |
| `fs.ls /buckets` | бакеты как папки filer |
| `fs.ls -l /buckets/my-bucket` | содержимое бакета |
| `fs.du /buckets/my-bucket` | размер бакета |
| `volume.list` | тома и их заполненность |
| `cluster.check` | проверка состояния |

Одной командой, без входа в консоль:

```bat
echo s3.bucket.list | docker exec -i seaweedfs weed shell
```

## Запасной вариант: docker run

Выполнять в cmd из папки `docker_conf` (`%cd%` — текущая папка).

```bat
docker run -d ^
  --name seaweedfs ^
  -p 8333:8333 -p 8888:8888 -p 9333:9333 ^
  -v "%cd%\seaweedfs\data:/data" ^
  -e AWS_ACCESS_KEY_ID=admin ^
  -e AWS_SECRET_ACCESS_KEY=admin123 ^
  chrislusf/seaweedfs server -s3
```
