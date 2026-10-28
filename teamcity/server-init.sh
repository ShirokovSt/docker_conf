#!/bin/bash
# Запуск сервера TeamCity (entrypoint в docker-compose.yml): подготовка, затем стандартный /run-services.sh образа.
#
# 1. Драйвер PostgreSQL: кнопка мастера качает его с download.jetbrains.com, а тот из РФ отвечает 451.
#    Поэтому драйвер берётся с Maven Central - только если его ещё нет в <data dir>/lib/jdbc
#    (штатное место по документации TeamCity).
# 2. В фоне ждём, пока сервер запустится (после первого старта - пока в мастере примут лицензию), и:
#    - если пользователей ещё нет, создаём TEAMCITY_ADMIN_USER / TEAMCITY_ADMIN_PASSWORD через REST API
#      с токеном суперпользователя, который сервер пишет в лог при каждом запуске;
#    - выставляем максимальный размер артефакта из TEAMCITY_MAX_ARTIFACT_MB (у TeamCity по умолчанию 300 МБ);
#    - если правила хранения логов билдов ещё нет, ставим его: 3 последних билда (log-retention.sh);
#    - дальше раз в минуту следим за билдами и после каждого завершённого запускаем очистку:
#      так логов у конфигурации не больше N (log-retention.sh), а не только после ночной очистки.

jdbc=/data/teamcity_server/datadir/lib/jdbc
ver=42.7.14
jar=postgresql-$ver.jar
if ! ls $jdbc/postgresql-*.jar >/dev/null 2>&1; then
  mkdir -p $jdbc
  curl -fsSL -o $jdbc/$jar.tmp https://repo.maven.apache.org/maven2/org/postgresql/postgresql/$ver/$jar \
    && mv $jdbc/$jar.tmp $jdbc/$jar && echo "JDBC driver: $jar downloaded" \
    || { rm -f $jdbc/$jar.tmp; echo "WARNING: JDBC driver download failed, see teamcity/README.md"; }
fi

init() {
  local tc=http://localhost:8111 c=/tmp/tc-cookies token csrf code
  until token=$(grep -ao 'Super user authentication token: [0-9]*' /opt/teamcity/logs/teamcity-server.log 2>/dev/null | tail -1 | grep -o '[0-9]*$') \
        && [ -n "$token" ] && curl -sf -o /dev/null -u ":$token" $tc/app/rest/server; do sleep 10; done

  if curl -s -u ":$token" -H 'Accept: application/json' "$tc/app/rest/users?fields=count" | grep -q '"count":0'; then
    csrf=$(curl -s -u ":$token" -c $c -b $c "$tc/authenticationTest.html?csrf")
    code=$(curl -s -o /dev/null -w '%{http_code}' -u ":$token" -c $c -b $c -H "X-TC-CSRF-Token: $csrf" \
      -H 'Content-Type: application/json' "$tc/app/rest/users" \
      -d "{\"username\":\"$TEAMCITY_ADMIN_USER\",\"password\":\"$TEAMCITY_ADMIN_PASSWORD\",\"roles\":{\"role\":[{\"roleId\":\"SYSTEM_ADMIN\",\"scope\":\"g\"}]}}")
    echo "TeamCity admin $TEAMCITY_ADMIN_USER: HTTP $code"
  fi

  # Максимальный размер артефакта (Administration -> Global Settings) - из TEAMCITY_MAX_ARTIFACT_MB
  local max=$(( ${TEAMCITY_MAX_ARTIFACT_MB:-1024} * 1024 * 1024 )) gs
  gs=$(curl -s -u ":$token" -H 'Accept: application/json' "$tc/app/rest/server/globalSettings")
  if [ -n "$gs" ] && ! printf '%s' "$gs" | grep -q "\"maxArtifactSize\":$max[,}]"; then
    printf '%s' "$gs" | sed "s/\"maxArtifactSize\":[0-9-]*/\"maxArtifactSize\":$max/" \
      | curl -s -o /dev/null -u ":$token" -X PUT -H 'Content-Type: application/json' --data @- "$tc/app/rest/server/globalSettings" \
      && echo "Max artifact size: ${TEAMCITY_MAX_ARTIFACT_MB:-1024} MB"
  fi

  local r=/opt/devstack/log-retention.sh
  if [ -z "$(sh $r get 2>/dev/null)" ]; then
    sh $r set 3 && echo "Build logs: kept for the last 3 builds (teamcity/log-retention.bat)"
  fi

  # Очистка после каждого завершённого билда, а не только ночью в 3:00: раз в минуту проверяем,
  # есть ли билды, завершённые после запомненного. Очистка с PostgreSQL идёт в фоне, сборкам не мешает.
  local q="$tc/app/rest/builds?locator=defaultFilter:false,state:finished" last n
  last=$(curl -s -u ":$token" "$q,count:1&fields=build(id)" | grep -o 'id="[0-9]*"' | grep -o '[0-9]*')
  while sleep 60; do
    if [ -n "$last" ]; then
      n=$(curl -s -u ":$token" "$q,sinceBuild:(id:$last),count:1000&fields=count" | grep -o 'count="[0-9]*"' | grep -o '[0-9]*')
    else
      n=$(curl -s -u ":$token" "$q,count:1000&fields=count" | grep -o 'count="[0-9]*"' | grep -o '[0-9]*')
    fi
    if [ "${n:-0}" -ge 1 ]; then
      sh $r now >/dev/null
      echo "Build logs: clean-up started after $n finished build(s)"
      last=$(curl -s -u ":$token" "$q,count:1&fields=build(id)" | grep -o 'id="[0-9]*"' | grep -o '[0-9]*')
    fi
  done
}

init &
exec /run-services.sh
