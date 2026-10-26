# Конвертер документов (LibreOffice + JODConverter)

Сервис, который превращает документы в PDF и другие форматы: docx → pdf, xlsx → pdf, odt → docx, html → pdf и т.д. Внутри LibreOffice, снаружи — HTTP API **LibreOffice Online** (`/lool/convert-to`). Подходит любому приложению, которое умеет работать с этим API.

| | |
|---|---|
| Адрес для приложений | `http://localhost:8095/lool/convert-to` |
| Swagger UI (ручная конвертация) | http://localhost:8095/swagger-ui.html |
| Проверка, что работает | http://localhost:8095/actuator/health → `{"status":"UP"}` |
| Логин | не нужен |
| Контейнер / сервис | `converter` |
| Версия | JODConverter REST 4.4.11 (образ `ghcr.io/jodconverter/jodconverter-examples:rest-4.4.11-1`) |
| Настройки | [application.properties](application.properties): лимит размера файла (100 МБ), число процессов LibreOffice, таймаут |
| Данные | нет — конвертер ничего не хранит |
| Память | ~0.5 ГБ (LibreOffice) |

Запуск: `start.bat`, остановка: `stop.bat`, логи: `logs.bat`. Всё сразу — `start-all.bat` или `start-services.bat` в корне. После старта контейнера LibreOffice запускается ещё 10–20 секунд.

## API

`/lool/convert-to` — стандартный путь конвертации **LibreOffice Online** («lool» = LibreOffice OnLine). Его же поддерживает Collabora Online (у неё новый вариант `/cool/convert-to`), а JODConverter повторяет этот API. Поэтому клиенту, написанному под LibreOffice Online, достаточно поменять адрес.

Запрос — `POST`, `multipart/form-data`:

| Поле | Обязательно | Что это |
|---|---|---|
| `data` | да | исходный файл |
| `format` | да, если формат не в пути | целевой формат: `pdf`, `docx`, `odt`, `xlsx`, `png`, `html`… |
| `password` | нет | пароль, если документ защищён |
| `l...`, `lf...`, `lfd...` | нет | параметры загрузки документа (load properties / filter / filter data) |
| `s...`, `sf...`, `sfd...` | нет | параметры сохранения (store properties / filter / filter data), например `sfdSelectPdfVersion=1` — PDF/A-1 |

Варианты адреса:
- `POST /lool/convert-to` + поле `format=pdf`;
- `POST /lool/convert-to/pdf` — формат в пути.

Ответ — сконвертированный файл (`200`). При ошибке — `400` (неверные параметры) или `500` (LibreOffice не справился).

## Ручная конвертация в Swagger UI

1. Откройте http://localhost:8095/swagger-ui.html.
2. Выберите `POST /lool/convert-to` → **Try it out**.
3. В `data` выберите файл, в `format` впишите `pdf` → **Execute**.
4. Внизу появится ссылка **Download file** — это результат.

## Команды

curl есть в Windows 10/11. Выполнять в папке с файлом.

| Команда | Что делает |
|---|---|
| `curl -F "data=@report.docx" -F "format=pdf" http://localhost:8095/lool/convert-to -o report.pdf` | docx → pdf |
| `curl -F "data=@report.docx" http://localhost:8095/lool/convert-to/pdf -o report.pdf` | то же, формат в пути |
| `curl -F "data=@report.docx" -F "format=pdf" -F "sfdSelectPdfVersion=1" http://localhost:8095/lool/convert-to -o report-pdfa.pdf` | docx → PDF/A-1 |
| `curl -F "data=@table.xlsx" -F "format=pdf" http://localhost:8095/lool/convert-to -o table.pdf` | xlsx → pdf |
| `curl -F "data=@page.html" -F "format=docx" http://localhost:8095/lool/convert-to -o page.docx` | html → docx |
| `curl http://localhost:8095/actuator/health` | проверка состояния |

Какие форматы поддерживаются — всё, что умеет LibreOffice: текстовые документы (doc, docx, odt, rtf, txt, html), таблицы (xls, xlsx, ods, csv), презентации (ppt, pptx, odp), а на выходе ещё pdf и картинки (png, jpg).

## Если образ не скачивается

Образ берётся не с Docker Hub, а с GitHub Container Registry (`ghcr.io`) — туда переехал проект JODConverter. Если `ghcr.io` недоступен, в `docker-compose.yml` у сервиса `converter` замените строку `image` на старый образ с Docker Hub:

```yaml
    image: eugenmayer/jodconverter:rest
```

API у него тот же (`/lool/convert-to`), но версия старая (январь 2022).

## Запасной вариант: docker run

Выполнять в cmd из папки `docker_conf` (`%cd%` — текущая папка).

```bat
docker run -d ^
  --name converter ^
  -p 8095:8080 ^
  -v "%cd%\converter\application.properties:/etc/app/application.properties:ro" ^
  ghcr.io/jodconverter/jodconverter-examples:rest-4.4.11-1
```
