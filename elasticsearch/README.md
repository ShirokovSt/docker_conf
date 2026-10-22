# Elasticsearch + Kibana

| | |
|---|---|
| Веб-интерфейс (Kibana) | http://localhost:5601 |
| Консоль запросов (Kibana Dev Tools) | http://localhost:5601/app/dev_tools#/console |
| REST API | http://localhost:9200 |
| Логин | не нужен (security выключен) |
| Контейнеры / сервисы | `elasticsearch`, `kibana` |
| Версия | 8.19.23, один узел, heap 1 ГБ |
| Данные | `elasticsearch/data` (индексы сохраняются после пересоздания) |

Запуск: `start.bat` (ES + Kibana), остановка: `stop.bat`, логи ES: `logs.bat`. Всё сразу — `start-all.bat` или `start-services.bat` в корне.

Kibana открывается через 1–2 минуты после старта: пока ES не готов, она показывает «Kibana server is not ready yet».

## Kibana Dev Tools

Самый удобный способ работать с ES: запросы с автодополнением, выполнение — Ctrl+Enter.

```
GET _cluster/health
GET _cat/indices?v&s=index

PUT my-index
{
  "mappings": {
    "properties": {
      "name":    { "type": "text" },
      "status":  { "type": "keyword" },
      "created": { "type": "date" }
    }
  }
}

POST my-index/_doc
{ "name": "hello world", "status": "new", "created": "2026-10-22" }

PUT my-index/_doc/1
{ "name": "документ с id 1", "status": "done", "created": "2026-10-22" }

GET my-index/_doc/1
GET my-index/_search
GET my-index/_search
{ "query": { "match": { "name": "hello" } } }

GET my-index/_search
{ "query": { "term": { "status": "new" } }, "size": 20 }

GET my-index/_mapping
GET my-index/_count
POST my-index/_delete_by_query
{ "query": { "term": { "status": "done" } } }

DELETE my-index
```

Просматривать документы в таблице: Kibana → Discover. Перед первым входом создайте Data View на нужный индекс, например `my-index*`.

## curl из cmd

curl есть в Windows 10/11. В cmd JSON пишется в двойных кавычках, внутренние кавычки экранируются `\"`. Адреса с `&` берите в кавычки.

| Команда | Что делает |
|---|---|
| `curl "http://localhost:9200/_cluster/health?pretty"` | состояние кластера (green/yellow — норма для одного узла) |
| `curl "http://localhost:9200/_cat/indices?v&s=index"` | список индексов |
| `curl -X PUT "http://localhost:9200/my-index"` | создать индекс |
| `curl -X POST "http://localhost:9200/my-index/_doc" -H "Content-Type: application/json" -d "{\"name\":\"hello\"}"` | добавить документ |
| `curl "http://localhost:9200/my-index/_search?q=name:hello&pretty"` | поиск |
| `curl "http://localhost:9200/my-index/_mapping?pretty"` | mapping индекса |
| `curl -X DELETE "http://localhost:9200/my-index"` | удалить индекс |

## Подключение из приложения

- URL: `http://localhost:9200`, без логина и TLS.
- Spring Boot: `spring.elasticsearch.uris=http://localhost:9200`.

## Запасной вариант: docker run

Выполнять в cmd из папки `docker_conf` (`%cd%` — текущая папка).

Без Kibana, только ES:

```bat
docker run -d ^
  --name elasticsearch ^
  -p 9200:9200 ^
  -v "%cd%\elasticsearch\data:/usr/share/elasticsearch/data" ^
  -e discovery.type=single-node ^
  -e xpack.security.enabled=false ^
  -e cluster.routing.allocation.disk.threshold_enabled=false ^
  -e "ES_JAVA_OPTS=-Xms1g -Xmx1g" ^
  elasticsearch:8.19.23
```
