#!/bin/sh
# Хранение логов и артефактов билдов TeamCity: правило очистки корневого проекта (project-config.xml).
# Выполняется внутри контейнера teamcity из log-retention.bat:  get | set N | now
#   get    - сколько последних успешных билдов каждой конфигурации хранят лог и артефакты (пусто - правила нет)
#   set N  - записать правило: старше N-го успешного билда лог и артефакты удаляются, история и тесты остаются
#   now    - запустить очистку сейчас (иначе она идёт сама каждую ночь в 3:00)
f=/data/teamcity_server/datadir/config/projects/_Root/project-config.xml
pat='+:**/*&#xA;+:.teamcity/logs/**'

case "$1" in
get)
  grep -o 'keepBuilds.count" value="[0-9]*' "$f" | grep -o '[0-9]*$'
  ;;
set)
  case "$2" in ''|*[!0-9]*) echo "нужно целое число" >&2; exit 2 ;; esac
  if grep -q 'keepBuilds.count' "$f"; then
    sed -i "s|name=\"keepBuilds.count\" value=\"[0-9]*\"|name=\"keepBuilds.count\" value=\"$2\"|" "$f"
  else
    sed -i "/<cleanup>/a\\
    <policy type=\"builds\" cleanup-level=\"ARTIFACTS\">\\
      <parameters>\\
        <param name=\"artifactPatterns\" value=\"$pat\" />\\
        <param name=\"keepBuilds.count\" value=\"$2\" />\\
      </parameters>\\
    </policy>" "$f"
  fi
  ;;
now)
  c=/tmp/tc-cleanup-cookies
  csrf=$(curl -s -u "$TEAMCITY_ADMIN_USER:$TEAMCITY_ADMIN_PASSWORD" -c $c -b $c "http://localhost:8111/authenticationTest.html?csrf")
  curl -s -o /dev/null -w '%{http_code}' -u "$TEAMCITY_ADMIN_USER:$TEAMCITY_ADMIN_PASSWORD" -c $c -b $c \
    -H "X-TC-CSRF-Token: $csrf" -d "cleanupPageAction=startCleanup" "http://localhost:8111/admin/cleanupPolicies.html"
  ;;
*)
  echo "get | set N | now" >&2
  exit 2
  ;;
esac
