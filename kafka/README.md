# Kafka + Kafka UI

| | |
|---|---|
| Веб-интерфейс (Kafka UI) | http://localhost:8080 — кластер `local` |
| Bootstrap для приложений на этом ПК | `localhost:9092` |
| Bootstrap для других контейнеров compose | `kafka:29092` |
| Логин | не нужен |
| Контейнеры / сервисы | `kafka`, `kafka-ui` |
| Версия | Apache Kafka 3.9.2, режим KRaft (без ZooKeeper), один брокер |
| Данные | `kafka/data` (топики и offset'ы сохраняются после пересоздания) |

Запуск: `start.bat` (Kafka + UI), остановка: `stop.bat`, логи брокера: `logs.bat`. Всё сразу — `start-all.bat` или `start-services.bat` в корне.

В Kafka UI можно: смотреть и создавать топики, читать сообщения (Messages), отправлять сообщения (Produce Message), смотреть consumer groups и их отставание (lag), менять настройки топиков.

## Команды из консоли

Скрипты Kafka лежат в контейнере в `/opt/kafka/bin`.

| Команда | Что делает |
|---|---|
| `docker exec kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list` | список топиков |
| `docker exec kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --create --topic test --partitions 3 --replication-factor 1` | создать топик |
| `docker exec kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic test` | партиции и настройки топика |
| `docker exec kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --delete --topic test` | удалить топик |
| `docker exec -it kafka /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic test` | отправлять сообщения: каждая строка — сообщение, выход Ctrl+C |
| `docker exec -it kafka /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic test --property parse.key=true --property key.separator=:` | то же с ключом: `key:value` |
| `docker exec -it kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test --from-beginning` | читать все сообщения с начала, выход Ctrl+C |
| `docker exec -it kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test --from-beginning --property print.key=true --property print.timestamp=true` | то же с ключами и временем |
| `docker exec kafka /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list` | список consumer groups |
| `docker exec kafka /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --group my-group` | offset'ы и lag группы |
| `docker exec kafka /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --group my-group --topic test --reset-offsets --to-earliest --execute` | перечитать топик с начала (группа должна быть остановлена) |
| `docker exec kafka /opt/kafka/bin/kafka-configs.sh --bootstrap-server localhost:9092 --alter --entity-type topics --entity-name test --add-config retention.ms=86400000` | хранить сообщения 1 сутки |

## Подключение из приложения

```properties
bootstrap.servers=localhost:9092
```

Spring Boot: `spring.kafka.bootstrap-servers=localhost:9092`.

## Запасной вариант: docker run

Выполнять в cmd из папки `docker_conf` (`%cd%` — текущая папка).

Без Kafka UI, только брокер:

```bat
docker run -d ^
  --name kafka ^
  -p 9092:9092 ^
  -v "%cd%\kafka\data:/var/lib/kafka/data" ^
  -e CLUSTER_ID=5L6g3nShT-eMCtK--X86sw ^
  -e KAFKA_NODE_ID=1 ^
  -e KAFKA_PROCESS_ROLES=broker,controller ^
  -e KAFKA_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093 ^
  -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9092 ^
  -e KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT ^
  -e KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER ^
  -e KAFKA_CONTROLLER_QUORUM_VOTERS=1@localhost:9093 ^
  -e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1 ^
  -e KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=1 ^
  -e KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=1 ^
  -e KAFKA_LOG_DIRS=/var/lib/kafka/data ^
  apache/kafka:3.9.2
```
