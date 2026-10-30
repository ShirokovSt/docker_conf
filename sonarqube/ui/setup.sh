#!/bin/sh
# Настройка SonarQube для локального стенда. Запускается фоном при старте sonarqube-ui (entrypoint.sh).
# Шаги безопасно повторять: при каждом запуске делается только то, что ещё не сделано.
#
# 1. Пароль администратора. У новой базы вход admin / admin, и SonarQube при первом входе требует сменить пароль.
#    Через Web API пароль короче 12 символов не задать, поэтому SONAR_ADMIN_PASSWORD (admin123) пишется прямо в базу
#    тем же хэшем, что у самого SonarQube: PBKDF2-HMAC-SHA512, 100000 итераций, ключ 512 бит, соль 20 байт;
#    crypted_password = "100000$<base64(хэш)>", salt = base64(соль). Пароль, сменённый в UI, не трогается.
# 2. Server base URL = SONAR_PUBLIC_URL: ссылки на отчёт ведут на адрес для браузера, даже если анализ шёл
#    изнутри Docker по http://sonarqube:9000.
# 3. Токены: devstack (тип Global Analysis) для анализа - в $TOKEN_FILE, его берёт analyze.sh; devstack-ui
#    (пользовательский) - в $UI_TOKEN_FILE, им страница анализа читает проекты и историю анализов.
#    Перестал подходить (отозвали в UI, база пересоздана) - выпускается новый.

sq=${SONAR_URL:-http://sonarqube:9000}
password=${SONAR_ADMIN_PASSWORD:-admin123}
admin="admin:$password"
token_file=${TOKEN_FILE:-/data/token}

log() { echo "setup: $*"; }

# POST в Web API от имени администратора; ответ - в stdout, ошибка - в лог (тело ответа объясняет причину)
api() {
  path=$1; shift
  out=$(curl -s -w '\n%{http_code}' -u "$admin" -X POST "$sq/api/$path" "$@")
  code=$(printf '%s' "$out" | tail -n 1)
  body=$(printf '%s' "$out" | sed '$d')
  case $code in
    2*) printf '%s' "$body" ;;
    *) log "$path -> HTTP $code $body" >&2; return 1 ;;
  esac
}

valid() { curl -s -u "$1" "$sq/api/authentication/validate" | grep -q '"valid":true'; }

set_admin_password() {
  salt_file=$(mktemp)
  openssl rand 20 > "$salt_file"
  salt=$(base64 < "$salt_file" | tr -d '\n')
  salt_hex=$(od -An -tx1 "$salt_file" | tr -d ' \n')
  rm -f "$salt_file"
  hash=$(openssl kdf -keylen 64 -kdfopt digest:SHA512 -kdfopt "pass:$password" -kdfopt "hexsalt:$salt_hex" \
    -kdfopt iter:100000 -binary PBKDF2 | base64 | tr -d '\n')
  updated=$(psql -d sonarqube -qtAc "UPDATE users SET crypted_password = '100000\$$hash', salt = '$salt',
      hash_method = 'PBKDF2', reset_password = false, updated_at = $(date +%s)000
    WHERE login = 'admin' AND user_local AND reset_password RETURNING login")
  [ -n "$updated" ] && log "admin password set (admin / $password)"
}

until curl -s "$sq/api/system/status" | grep -q '"status":"UP"'; do sleep 5; done

set_admin_password
# новый пароль из базы SonarQube принимает не мгновенно
tries=0
until valid "$admin"; do
  tries=$((tries + 1))
  if [ $tries -ge 15 ]; then
    log "admin / $password is not valid (password changed in UI?) - token skipped"
    exit 0
  fi
  sleep 2
done

[ -n "$SONAR_PUBLIC_URL" ] && api settings/set -d key=sonar.core.serverBaseURL --data-urlencode "value=$SONAR_PUBLIC_URL" >/dev/null

# Токен: есть и подходит - оставить; нет - выпустить (имя, тип, файл)
issue_token() {
  name=$1 type=$2 file=$3
  token=$(cat "$file" 2>/dev/null)
  if [ -n "$token" ] && valid "$token:"; then
    return
  fi
  # токен с тем же именем мог остаться в базе - имя должно быть свободно
  api user_tokens/revoke -d login=admin -d name="$name" >/dev/null 2>&1
  token=$(api user_tokens/generate -d login=admin -d name="$name" -d type="$type" \
    | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
  if [ -n "$token" ]; then
    printf '%s' "$token" > "$file" && log "token $name created ($file)"
  fi
}
issue_token devstack GLOBAL_ANALYSIS_TOKEN "$token_file"
# страница анализа читает проекты и историю анализов - для этого токена анализа мало
issue_token devstack-ui USER_TOKEN "${UI_TOKEN_FILE:-/data/ui-token}"
