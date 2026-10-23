# Spark (Spark Connect) + File Browser

| | |
|---|---|
| Подключение (Spark Connect) | `sc://localhost:15002` |
| Spark UI (задачи, SQL, этапы) | http://localhost:4040 |
| Файлы Spark (File Browser) | http://localhost:8090 — без логина |
| Папка с файлами | `spark\data` на диске = `/data` внутри Spark |
| Логин | не нужен |
| Контейнеры / сервисы | `spark`, `spark-files` |
| Версия | Spark 3.5.2 (Scala 2.12, Java 17), режим `local[*]` |
| Настройки | [conf/spark-defaults.conf](conf/spark-defaults.conf) |
| Свои jar (classpath Spark) | папка `spark\jars` — см. [jars/README.md](jars/README.md) |

Запуск: `start.bat` (Spark + File Browser), остановка: `stop.bat`, логи Spark: `logs.bat`. Всё сразу — `start-all.bat` или `start-services.bat` в корне.

**Первый запуск — до минуты.** В Spark 3.5 модуль Spark Connect не входит в дистрибутив, при первом старте он скачивается из Maven Central (нужен интернет) и кэшируется в `spark\ivy`. Следующие запуски — без интернета, за несколько секунд. Сервер готов, когда в `logs.bat` появится строка про `Spark Connect server started` на порту 15002.

## Свои jar

Папка `spark\jars` — для jar, которые должны быть на сервере Spark заранее: драйверы JDBC, коннекторы, библиотеки для UDF и источников данных. Все `*.jar` из неё при старте попадают в classpath Spark (`spark.driver.extraClassPath` в `spark-defaults.conf`).

- Положили или заменили jar — перезапустите Spark: `docker compose restart spark` или `stop.bat` + `start.bat`.
- Jar должны подходить к Spark 3.5.2 / Scala 2.12.
- Содержимое папки в git не попадает (кроме её README).
- Проверить, что jar видны Spark: `docker exec spark ls /opt/spark/extra-jars`, а в Spark UI на вкладке Environment они есть в Classpath Entries.

Отличие от `addArtifact`: jar, который приложение отправляет через Spark Connect, живёт только в своей сессии. Jar из `spark\jars` доступны всегда и всем сессиям — так подключаются тяжёлые зависимости, драйверы JDBC и форматы источников данных.

## Без Hadoop

- Hadoop-кластер не нужен и не запускается: нет HDFS, YARN, NameNode и т.п.
- Spark работает в режиме `local[*]`: драйвер и исполнители в одном контейнере, используются все ядра.
- В Spark встроены клиентские библиотеки Hadoop (jar внутри образа). Через них Spark читает и пишет обычные файлы. Это часть Spark, настраивать их не нужно.
- `winutils.exe` и `HADOOP_HOME` на Windows не нужны: Spark работает в Linux-контейнере, а приложение на Windows подключается тонким клиентом Spark Connect.
- В логах может быть предупреждение `Unable to load native-hadoop library` — это норма, на работу не влияет.
- Вместо HDFS — папка `spark\data`.

## Файлы

Папка `spark\data` — одно и то же место в трёх видах:

| Где | Как выглядит |
|---|---|
| File Browser | http://localhost:8090 — корень |
| Проводник | `docker_conf\spark\data\` |
| Код Spark | `test.json` или `/data/test.json` — одно и то же |

В File Browser можно:
- загружать файлы и папки (кнопка Upload или перетаскиванием);
- скачивать, в том числе несколько сразу архивом;
- удалять, переименовывать, перемещать;
- создавать папки;
- просматривать и редактировать текстовые файлы (csv, json, txt);
- искать по имени.

Пути в коде — это пути **на стороне Spark**, а не `C:\...`. Рабочая папка Spark — `/data`, поэтому путь без папки (`test.json`, `input/test.json`) ищется прямо в `spark\data`, то есть так, как вы видите файлы в File Browser. Полный путь `/data/...` тоже работает. Результаты, записанные в `/data/out`, сразу видны в File Browser и в проводнике.

## Подключение из приложения

Зависимости клиента — той же версии, что и сервер (3.5.2):

```xml
<dependency>
  <groupId>org.apache.spark</groupId>
  <artifactId>spark-connect-client-jvm_2.12</artifactId>
  <version>3.5.2</version>
</dependency>
<dependency>
  <groupId>org.apache.spark</groupId>
  <artifactId>spark-sql-api_2.12</artifactId>
  <version>3.5.2</version>
</dependency>
```

```properties
spark.connectUrl=sc://localhost:15002
```

```java
SparkSession spark = SparkSession.builder().remote("sc://localhost:15002").build();

Dataset<Row> df = spark.read().option("header", "true").csv("/data/input.csv");
df.show();
df.write().mode("overwrite").parquet("/data/out/input_parquet");
```

- **UDF и лямбды** (`map`, `filter` с функцией, свои UDF) выполняются на сервере, поэтому их классы надо передать: `spark.addArtifact("<путь к jar>")` или `spark.registerClassFinder(...)`. Обычные DataFrame/SQL-операции работают без этого.
- **Таблицы.** `saveAsTable` пишет файлы в `/data/warehouse`, но каталог таблиц хранится в памяти и сбрасывается при перезапуске Spark. Для данных, которые должны жить дольше, читайте и пишите файлы (parquet, csv, json) по путям в `/data`.

## Spark UI

http://localhost:4040 — работает, пока запущен Spark:

| Вкладка | Что там |
|---|---|
| Jobs, Stages | задачи и этапы, время, ошибки |
| SQL / DataFrame | планы запросов от приложения |
| Storage | закэшированные данные |
| Environment | настройки |
| Executors | память и ядра |

Каждый запрос из приложения через Spark Connect виден здесь.

## Команды

| Команда | Что делает |
|---|---|
| `docker exec -it spark /opt/spark/bin/spark-sql` | SQL-консоль (отдельная локальная сессия, тоже видит `/data`), выход — `exit;` |
| `SELECT * FROM csv.`/data/input.csv`;` | в spark-sql: прочитать CSV без создания таблицы |
| `SELECT * FROM parquet.`/data/out/input_parquet`;` | прочитать parquet |
| `docker exec spark ls -la /data` | содержимое папки данных |
| `docker compose restart spark` | перезапуск после правки `spark-defaults.conf` |

Память Spark задаётся в `spark-defaults.conf` (`spark.driver.memory`, сейчас 2 ГБ).

## Запасной вариант: docker run

Выполнять в cmd из папки `docker_conf` (`%cd%` — текущая папка).

```bat
docker run -d ^
  --name spark ^
  -w /data ^
  -p 15002:15002 -p 4040:4040 ^
  -v "%cd%\spark\data:/data" ^
  -v "%cd%\spark\conf\spark-defaults.conf:/opt/spark/conf/spark-defaults.conf:ro" ^
  -v "%cd%\spark\jars:/opt/spark/extra-jars:ro" ^
  -v "%cd%\spark\ivy:/opt/spark/ivy" ^
  -e SPARK_NO_DAEMONIZE=true ^
  -e SPARK_LOG_DIR=/tmp/spark-logs ^
  spark:3.5.2-scala2.12-java17-ubuntu ^
  /opt/spark/sbin/start-connect-server.sh --packages org.apache.spark:spark-connect_2.12:3.5.2

docker run -d ^
  --name spark-files ^
  -p 8090:80 ^
  -v "%cd%\spark\data:/srv" ^
  filebrowser/filebrowser:v2.63.23 --noauth
```
