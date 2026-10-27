#!/bin/sh
# Хранение логов и артефактов билдов TeamCity. Выполняется внутри контейнера teamcity:
# из log-retention.bat и из server-init.sh (при первом запуске и после каждого завершённого билда).
#   get    - у скольких последних билдов каждой конфигурации хранятся логи и артефакты (пусто - не настроено)
#   set N  - хранить логи и артефакты N последних билдов любого статуса; история и тесты остаются у всех
#   now    - запустить очистку сейчас (сама она идёт после каждого билда и каждую ночь в 3:00)
#
# Как устроено (корневой проект, видно в Root project -> Clean-up Rules):
# - базовое правило: логи и артефакты всех билдов на очистку (0 дней). В UI 0 не задать, поэтому - в
#   project-config.xml; публичного API для базового правила нет. Перед правкой - копия файла и проверка;
# - keep rule (публичный REST API): N последних билдов сохраняются целиком.
# Сами по себе базовые правила TeamCity считают только успешные билды, поэтому N любых - только так.
tc=http://localhost:8111
auth="$TEAMCITY_ADMIN_USER:$TEAMCITY_ADMIN_PASSWORD"
f=/data/teamcity_server/datadir/config/projects/_Root/project-config.xml
features="$tc/app/rest/projects/id:_Root/projectFeatures"
log=/opt/teamcity/logs/teamcity-server.log

# id keep rule "N последних билдов целиком" (пусто - нет)
rule_id() {
  for id in $(curl -s -u "$auth" "$features?locator=type:keepRules&fields=projectFeature(id)" | grep -o 'KEEP_RULE_[0-9]*'); do
    [ "$(curl -s -u "$auth" "$features/id:$id/properties/limit.type")" = lastNBuilds ] \
      && [ "$(curl -s -u "$auth" "$features/id:$id/properties/keepData.1.type")" = everything ] \
      && { echo "$id"; return 0; }
  done
}

get() {
  id=$(rule_id)
  [ -n "$id" ] || return 0
  grep -q '<policy type="days" cleanup-level="ARTIFACTS">' "$f" || return 0
  curl -s -u "$auth" "$features/id:$id/properties/limit.buildsCount"
  echo
}

# базовое правило: логи и артефакты всех билдов - на очистку (оставит только keep rule)
set_base() {
  grep -q '<policy type="days" cleanup-level="ARTIFACTS">' "$f" && return 0
  # правку файла сразу после записи настроек самим сервером (keep rule выше) он не замечает - выждать
  sleep 10
  # копия до правки: неудачная замена не должна испортить настройки корневого проекта
  cp "$f" "$f.bak"
  policy='<policy type="days" cleanup-level="ARTIFACTS"><parameters><param name="artifactPatterns" value="+:**/*\&#xA;+:.teamcity/logs/**" /><param name="keepDays.count" value="0" /></parameters></policy>'
  # прежнее правило "N последних успешных" (старые версии этого скрипта) - убрать
  sed -i '/<policy type="builds" cleanup-level="ARTIFACTS">/,/<\/policy>/d' "$f"
  if grep -q '<cleanup>' "$f"; then
    sed -i "s|<cleanup>|<cleanup>$policy|" "$f"
  elif grep -q '<cleanup */>' "$f"; then
    sed -i "s|<cleanup */>|<cleanup>$policy</cleanup>|" "$f"
  else
    sed -i "s|</project>|<cleanup>$policy</cleanup></project>|" "$f"
  fi
  if ! grep -q 'keepDays.count" value="0"' "$f"; then
    cp "$f.bak" "$f"
    echo "не удалось записать базовое правило в $f - файл возвращён как был" >&2
    return 1
  fi
  # сервер перечитывает файл сам (обычно за 15-30 секунд); запись настроек через UI или REST до этого
  # вернула бы старое правило из памяти - поэтому ждём. Изменение он иногда пропускает - touch раз в 30 с.
  t=$(date -u '+%Y-%m-%d %H:%M:%S')
  i=0
  until grep -a 'Finished reloading projects configuration' "$log" | tail -1 | cut -c2-20 | awk -v t="$t" '$0 >= t {ok=1} END {exit !ok}'; do
    i=$((i + 1)); [ $i -gt 60 ] && { echo "сервер не перечитал $f за 3 минуты" >&2; return 1; }
    [ $((i % 10)) -eq 0 ] && touch "$f"
    sleep 3
  done
}

case "$1" in
get)
  get
  ;;
set)
  case "$2" in ''|*[!0-9]*|0) echo "нужно целое число больше 0" >&2; exit 2 ;; esac
  [ -f "$f" ] || { echo "нет $f - сервер ещё не настроен" >&2; exit 1; }
  # сначала keep rule (REST), потом базовое правило (файл): наоборот REST перезаписал бы файл из памяти
  id=$(rule_id)
  if [ -n "$id" ]; then
    curl -s -o /dev/null -u "$auth" -X PUT -H 'Content-Type: text/plain' --data "$2" "$features/id:$id/properties/limit.buildsCount"
  else
    curl -s -o /dev/null -u "$auth" -X POST -H 'Content-Type: application/json' "$features" --data \
      "{\"type\":\"keepRules\",\"properties\":{\"property\":[{\"name\":\"limit.type\",\"value\":\"lastNBuilds\"},{\"name\":\"limit.buildsCount\",\"value\":\"$2\"},{\"name\":\"keepData.1.type\",\"value\":\"everything\"},{\"name\":\"preserveArtifacts\",\"value\":\"true\"},{\"name\":\"ruleDisabled\",\"value\":\"false\"}]}}"
  fi
  set_base || exit 1
  if [ "$(get)" != "$2" ]; then
    echo "правило не записалось - проверьте Root project -> Clean-up Rules" >&2
    exit 1
  fi
  ;;
now)
  c=/tmp/tc-cleanup-cookies
  csrf=$(curl -s -u "$auth" -c $c -b $c "$tc/authenticationTest.html?csrf")
  curl -s -o /dev/null -w '%{http_code}' -u "$auth" -c $c -b $c \
    -H "X-TC-CSRF-Token: $csrf" -d "cleanupPageAction=startCleanup" "$tc/admin/cleanupPolicies.html"
  ;;
*)
  echo "get | set N | now" >&2
  exit 2
  ;;
esac
