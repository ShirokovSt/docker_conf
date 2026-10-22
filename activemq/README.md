# ActiveMQ Classic

| | |
|---|---|
| Веб-консоль | http://localhost:8161/admin — логин `admin` / `admin123` |
| OpenWire (JMS) | `tcp://localhost:61616` |
| AMQP | `amqp://localhost:5672` |
| STOMP | `stomp://localhost:61613` |
| MQTT | `tcp://localhost:1883` |
| WebSocket (STOMP/MQTT) | `ws://localhost:61614` |
| Логин для клиентов | не нужен (подключение без авторизации) |
| Контейнер / сервис | `activemq` |
| Версия | ActiveMQ Classic 5.18.7 |
| Данные | `activemq/data`: хранилище сообщений KahaDB и лог `activemq.log` |

Запуск: `start.bat`, остановка: `stop.bat`, логи: `logs.bat`. Всё сразу — `start-all.bat` или `start-services.bat` в корне.

Логин и пароль относятся только к веб-консоли. Приложения подключаются к брокеру без логина, как у ActiveMQ по умолчанию.

## Веб-консоль

| Раздел | Что там |
|---|---|
| **Queues** | очереди: сообщения в ожидании, число consumer'ов, enqueued/dequeued. Создать очередь — поле сверху + Create. Клик по очереди — список сообщений: просмотр, удаление, перенос в другую очередь. **Purge** — очистить очередь, **Delete** — удалить. |
| **Topics** | топики и их подписчики |
| **Subscribers** | durable-подписки |
| **Connections** | подключённые клиенты по протоколам |
| **Scheduled** | отложенные сообщения (если включён scheduler) |
| **Send** | отправить сообщение в очередь или топик вручную: Destination, тело, заголовки, количество |

## Команды из консоли

Утилита `activemq` в контейнере: `/opt/apache-activemq/bin/activemq`.

| Команда | Что делает |
|---|---|
| `docker exec activemq /opt/apache-activemq/bin/activemq producer --destination queue://test --messageCount 10 --message "hello"` | отправить 10 сообщений в очередь `test` |
| `docker exec activemq /opt/apache-activemq/bin/activemq consumer --destination queue://test --messageCount 10` | прочитать 10 сообщений из очереди |
| `docker exec activemq /opt/apache-activemq/bin/activemq producer --destination topic://events --messageCount 5` | отправить в топик |
| `docker exec activemq /opt/apache-activemq/bin/activemq dstat queues` | статистика очередей |
| `docker exec activemq /opt/apache-activemq/bin/activemq purge test` | очистить очередь `test` |
| `docker exec activemq tail -n 100 /opt/apache-activemq/data/activemq.log` | лог брокера |

Если `dstat` или `purge` не подключаются к JMX внутри контейнера, сделайте то же в веб-консоли: Queues → Purge.

## Подключение из приложения

```properties
# Spring Boot
spring.activemq.broker-url=tcp://localhost:61616
```

JMS: `new ActiveMQConnectionFactory("tcp://localhost:61616")`.

## Запасной вариант: docker run

Выполнять в cmd из папки `docker_conf` (`%cd%` — текущая папка).

```bat
docker run -d ^
  --name activemq ^
  -p 8161:8161 -p 61616:61616 -p 5672:5672 -p 61613:61613 -p 1883:1883 -p 61614:61614 ^
  -v "%cd%\activemq\data:/opt/apache-activemq/data" ^
  -e ACTIVEMQ_WEB_USER=admin ^
  -e ACTIVEMQ_WEB_PASSWORD=admin123 ^
  apache/activemq-classic:5.18.7
```
