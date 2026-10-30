#!/bin/sh
# Анализ Maven- или Gradle-проекта в SonarQube. Запускается в контейнере sonarqube-ui: кнопкой на странице
# анализа (server.js) или из sonarqube\analyze.bat (docker exec).
#   analyze.sh <папка /host/...> [notests] [JDK] [ключ проекта]   - после папки в любом порядке
#   notests - без тестов (быстрее, но без покрытия); JDK - число (по умолчанию 21); ключ - проект в SonarQube
#   (по умолчанию из сборки: groupId:artifactId у Maven, group:имя у Gradle).
# Код возврата: 0 - отчёт отправлен, 1 - ошибка, 2 - эта папка уже анализируется.
#
# Сборка идёт в отдельном контейнере sonarqube-build-* (образ с нужной JDK) в сети devstack; папка проекта - /src.
# Анализы разных папок могут идти одновременно.
# Пути: этот контейнер видит диски ПК как /host/<диск>/..., Docker - как /run/desktop/mnt/host/<диск>/...
# pom.xml и build.gradle не меняются: сканер SonarQube и JaCoCo (покрытие тестами) подключаются при запуске -
# у Maven полными именами целей плагинов, у Gradle init-скриптом (ниже, передаётся в контейнер переменной).
# Тесты с Testcontainers работают: сборке дан Docker этого ПК (docker.sock), их контейнеры запускаются рядом.

DEFAULT_JDK=${DEFAULT_JDK:-21}
# Сканеру SonarQube нужна Java 11+: при JDK ниже он запускается вторым шагом по готовой сборке
SCANNER_JDK=11
MAVEN_VERSION=${MAVEN_VERSION:-3.9.16}
# Gradle из образа - для проектов без wrapper (с wrapper берётся версия проекта). Gradle 9 работает на JDK 17+.
GRADLE_VERSION=${GRADLE_VERSION:-9.8.2}
GRADLE_VERSION_OLD_JDK=8.14.6
# JaCoCo без версии: если он уже есть в pom, Maven возьмёт ту же версию (два агента разных версий роняют тесты)
JACOCO=org.jacoco:jacoco-maven-plugin
SONAR_MAVEN=org.sonarsource.scanner.maven:sonar-maven-plugin:5.8.0.7211
# Для Gradle старше 7.3 (плагин SonarQube с ним не работает) отчёт отправляет SonarScanner CLI
SCANNER_CLI=sonarsource/sonar-scanner-cli:12.2.0.4256_8.1.0
SONAR_URL=${SONAR_URL:-http://sonarqube:9000}
TOKEN_FILE=${TOKEN_FILE:-/data/token}
BUILD=sonarqube-build-$(date +%s)-$$

fail() { echo "[!] $*"; exit 1; }

# ---------- аргументы ----------
src=${1%/}
[ -n "$src" ] || fail "Не указана папка проекта"
shift
notests= jdk= key=
for a in "$@"; do
  case $a in
    notests) notests=1 ;;
    *[!0-9]*) key=$a ;;
    ?*) jdk=$a ;;
  esac
done
jdk=${jdk:-$DEFAULT_JDK}

case $src in /host/*) ;; *) fail "Папка должна быть внутри /host (диски ПК): $src" ;; esac
[ -d "$src" ] || fail "Папка не найдена или не видна стенду: $src"
if [ -f "$src/pom.xml" ]; then
  build=maven
elif [ -f "$src/build.gradle" ] || [ -f "$src/build.gradle.kts" ] || [ -f "$src/settings.gradle" ] || [ -f "$src/settings.gradle.kts" ]; then
  build=gradle
else
  fail "В $src нет pom.xml или build.gradle - нужна корневая папка Maven- или Gradle-проекта"
fi
# Плагин SonarQube для Gradle работает с Gradle 7.3+. Со старым Gradle проект собирается им же (на JDK до 11 -
# на более новых он не запускается), а отчёт отправляет SonarScanner CLI (scan_cli ниже).
legacy=
wrapper_props=$src/gradle/wrapper/gradle-wrapper.properties
if [ "$build" = gradle ] && [ -f "$wrapper_props" ]; then
  gver=$(sed -nE 's/^distributionUrl=.*gradle-([0-9][0-9.]*)-(bin|all)\.zip.*/\1/p' "$wrapper_props")
  gmajor=${gver%%.*}; grest=${gver#*.}; gminor=${grest%%.*}
  if [ -n "$gmajor" ] && { [ "$gmajor" -lt 7 ] || { [ "$gmajor" -eq 7 ] && [ "${gminor:-0}" -lt 3 ]; }; }; then
    legacy=1
    if [ "$jdk" -gt 11 ]; then
      echo "У проекта Gradle $gver - он работает на JDK до 11, сборка пойдёт на JDK 11"
      jdk=11
    fi
  fi
fi

# две сборки одной папки писали бы в одни и те же build / target
if [ -n "$(docker ps -q -f "label=devstack.src=$src")" ]; then
  echo "[!] Эта папка уже анализируется. Дождитесь окончания или остановите тот анализ."
  exit 2
fi

# ---------- SonarQube и токен (выпускает setup.sh) ----------
waited=
while :; do
  token=$(cat "$TOKEN_FILE" 2>/dev/null)
  if [ -n "$token" ] && curl -s -u "$token:" "$SONAR_URL/api/authentication/validate" | grep -q '"valid":true'; then
    break
  fi
  [ -z "$waited" ] && echo "Жду, пока SonarQube будет готов (первый запуск - 1-3 минуты)..."
  waited=$((${waited:-0} + 5))
  [ "$waited" -ge 300 ] && fail "SonarQube не готов за 5 минут - смотрите sonarqube\\logs.bat"
  sleep 5
done

# ---------- монтирования ----------
host_path() { echo "/run/desktop/mnt/host${1#/host}"; }
# C:\Users\name -> /host/c/Users/name
win_to_host() {
  printf '/host/%s%s' "$(printf '%s' "$1" | cut -c1 | tr 'A-Z' 'a-z')" "$(printf '%s' "$1" | cut -c3- | tr '\\' '/')"
}

m2= gradle_vol= gprops=
userprofile=$(win_to_host "$HOST_USERPROFILE")
if [ "$build" = maven ] && [ -n "$HOST_USERPROFILE" ]; then
  # .m2 пользователя: settings.xml (приватный Nexus) и уже скачанные зависимости
  m2="$(host_path "$userprofile")/.m2"
fi
if [ "$build" = gradle ]; then
  # Кеш Gradle - в своём томе, не в %USERPROFILE%\.gradle: с Gradle-демоном IDEA они мешали бы друг другу
  # блокировками. По той же причине у одновременных сборок кеши разные: первая берёт основной
  # devstack-gradle-cache, следующие - devstack-gradle-cache-2, -3... (свободный держим блокировкой до конца анализа).
  mkdir -p /tmp/gradle-cache-locks
  n=1
  while [ $n -le 9 ]; do
    vol=devstack-gradle-cache
    [ $n -gt 1 ] && vol=devstack-gradle-cache-$n
    exec 8>"/tmp/gradle-cache-locks/$n"
    if flock -n 8 && [ -z "$(docker ps -q -f "volume=$vol")" ]; then
      gradle_vol=$vol
      break
    fi
    n=$((n + 1))
  done
  [ -n "$gradle_vol" ] || fail "Все кеши Gradle заняты другими анализами"
  [ "$gradle_vol" != devstack-gradle-cache ] && echo "Основной кеш Gradle занят другим анализом - отдельный кеш $gradle_vol"
  # gradle.properties пользователя (логины приватного Nexus) - если есть и виден стенду
  if [ -n "$HOST_USERPROFILE" ] && [ -f "$userprofile/.gradle/gradle.properties" ]; then
    gprops="$(host_path "$userprofile")/.gradle/gradle.properties"
  fi
fi

# Образ сборки: есть на ПК - сразу, нет - скачать; не скачался - объяснить
pull() {
  docker image inspect "$1" >/dev/null 2>&1 && return 0
  echo "Скачивание образа $1 ..."
  docker pull -q "$1" && return 0
  echo "[!] Образ $1 не скачался с Docker Hub."
  echo "    \"not found\" - такого тега нет: проверьте номер JDK (теги - на hub.docker.com, страницы maven и gradle)."
  echo "    \"TLS handshake timeout\" / \"timed out\" - у Docker Desktop нет выхода в интернет (VPN, прокси)."
  return 1
}

# Сборка в фоне + wait: так «Остановить» (SIGTERM) прерывает и контейнер
trap 'echo; echo "[!] Анализ остановлен"; docker stop -t 10 "$BUILD" >/dev/null 2>&1; exit 130' INT TERM
run() {
  image=$1; shift
  pull "$image" || return 1
  set -- "$image" "$@"
  [ -n "$gprops" ] && set -- -v "$gprops:/gradle-home/gradle.properties:ro" "$@"
  [ -n "$gradle_vol" ] && set -- -e GRADLE_USER_HOME=/gradle-home -v "$gradle_vol:/gradle-home" "$@"
  [ -n "$m2" ] && set -- -v "$m2:/root/.m2" "$@"
  docker run --rm --name "$BUILD" --label "devstack.src=$src" --network devstack_default \
    -v "$(host_path "$src"):/src" -w /src \
    -v /var/run/docker.sock:/var/run/docker.sock -e TESTCONTAINERS_HOST_OVERRIDE=host.docker.internal \
    -e SONAR_HOST_URL="$SONAR_URL" -e SONAR_TOKEN="$token" -e SONAR_INIT_GRADLE \
    "$@" &
  wait $!
}

# Init-скрипт Gradle: подключает к проекту то, чего в нём нет (build.gradle не меняется):
#   - плагин org.sonarqube (задача sonar) - в корневой проект; свой плагин проекта не трогается;
#   - JaCoCo с XML-отчётом - во все Java/Kotlin-модули; упавшие тесты анализ не останавливают;
#   - foojay - Gradle сам скачивает JDK из java.toolchain, если в контейнере другая.
# Плагин SonarQube требует Java 11+ и Gradle 7.3+, foojay - Java 17+ и Gradle 7.6+: на более старых не подключаются.
gradle_init() {
  cat <<'GRADLE'
initscript {
    repositories {
        gradlePluginPortal()
    }
    dependencies {
        def java = JavaVersion.current().majorVersion.toInteger()
        def gradleAtLeast = { String v -> org.gradle.util.GradleVersion.current() >= org.gradle.util.GradleVersion.version(v) }
        if (java >= 11 && gradleAtLeast('7.3')) {
            classpath 'org.sonarsource.scanner.gradle:sonarqube-gradle-plugin:7.5.0.8588'
        }
        if (java >= 17 && gradleAtLeast('7.6')) {
            classpath 'org.gradle.toolchains:foojay-resolver:1.0.0'
        }
    }
}

// плагин в classpath только если подошёл по Java и Gradle; нет - null
def pluginClass = { String name ->
    try { Class.forName(name, true, getClass().classLoader) } catch (ClassNotFoundException ignored) { null }
}
def foojay = pluginClass('org.gradle.toolchains.foojay.FoojayToolchainsConventionPlugin')
def sonarqube = pluginClass('org.sonarqube.gradle.SonarQubePlugin')

settingsEvaluated { settings ->
    if (foojay && !settings.pluginManager.hasPlugin('org.gradle.toolchains.foojay-resolver-convention')) {
        try {
            settings.pluginManager.apply(foojay)
        } catch (Throwable e) {
            logger.warn("init: foojay не подключён (${e.message})")
        }
    }
}

allprojects {
    pluginManager.withPlugin('java') {
        pluginManager.apply('jacoco')
        tasks.named('jacocoTestReport') {
            // Gradle 7+: required, раньше - enabled
            if (reports.xml.hasProperty('required')) { reports.xml.required = true } else { reports.xml.enabled = true }
        }
        tasks.withType(Test).configureEach {
            ignoreFailures = true
            // Если сборка передаёт тестам свойства JVM Gradle (systemProperties = System.props), user.dir у тестов -
            // корень проекта, а путь к агенту JaCoCo - относительно папки модуля. Рабочая папка = user.dir:
            // пути сходятся, для тестов ничего не меняется (Java и так считает текущей папкой user.dir).
            doFirst {
                def userDir = systemProperties['user.dir']
                if (userDir && file(userDir) != workingDir) {
                    workingDir = file(userDir)
                }
            }
        }
    }
}

rootProject {
    // свой org.sonarqube в проекте - второй раз не применяем (две версии плагина конфликтуют)
    def buildFile = ['build.gradle', 'build.gradle.kts'].collect { file(it) }.find { it.exists() }
    if (buildFile?.text?.contains('org.sonarqube')) {
        return
    }
    if (!sonarqube) {
        return // старый Gradle или JDK 8: отчёт отправляется отдельным шагом (analyze.sh)
    }
    pluginManager.apply(sonarqube)
    gradle.projectsEvaluated {
        // Gradle-проекты без своей папки на диске: исходников в них нет, а сканер на такой папке падает
        allprojects { p ->
            if (!p.projectDir.exists()) {
                p.extensions.findByName('sonar')?.skipProject = true
            }
        }
        // Модули - отдельные git-репозитории внутри корня: для корневого git это неотслеживаемые файлы, и сканер
        // исключил бы их как игнорируемые. Тогда исключения по git выключаются.
        def nestedRepo = { File dir ->
            for (def d = dir; d != null && d != rootDir; d = d.parentFile) {
                if (new File(d, '.git').exists()) return true
            }
            false
        }
        if (subprojects.any { it.projectDir.exists() && nestedRepo(it.projectDir) }) {
            extensions.findByName('sonar')?.properties { it.property('sonar.scm.exclusions.disabled', 'true') }
        }
    }
}
GRADLE
}

# Отчёт для старого Gradle: SonarScanner CLI по готовой сборке. Исходники, тесты, классы и отчёты JaCoCo ищутся
# в папках модулей (стандартная раскладка src/main|test/java|kotlin), типы библиотек - в кеше Gradle.
found() { # глубина, тип (d/f), шаблон пути -> пути от корня проекта через запятую
  find "$src" -maxdepth "$1" \( -name node_modules -o -name .git -o -name .gradle \) -prune -o -type "$2" -path "$3" -print \
    | sed "s#^$src/##" | sort | tr '\n' ',' | sed 's/,$//'
}
scan_cli() {
  echo; echo "Отправка в SonarQube (SonarScanner CLI: у проекта Gradle $gver) ..."
  sources=$(found 6 d '*/src/main/*' | tr ',' '\n' | grep -E '(^|/)src/main/(java|kotlin)$' | grep -v '/build/' | paste -sd, -)
  tests=$(found 6 d '*/src/test/*' | tr ',' '\n' | grep -E '(^|/)src/test/(java|kotlin)$' | grep -v '/build/' | paste -sd, -)
  binaries=$(found 7 d '*/build/classes/*/main')
  coverage=$(found 7 f '*/build/reports/jacoco/test/jacocoTestReport.xml')
  [ -n "$sources" ] || { echo "[!] Не найдены исходники (src/main/java, src/main/kotlin)"; return 1; }
  name=$(sed -nE "s/^ *rootProject\.name *= *['\"]([^'\"]+)['\"].*/\1/p" "$src"/settings.gradle* 2>/dev/null | head -n 1)
  name=${name:-${src##*/}}
  # рабочая папка - в проекте: там report-task.txt со ссылкой на отчёт
  run "$SCANNER_CLI" -Dsonar.projectBaseDir=/src -Dsonar.working.directory=/src/.scannerwork \
    -Dsonar.projectKey="${key:-$name}" -Dsonar.projectName="$name" \
    -Dsonar.sources="$sources" ${tests:+-Dsonar.tests="$tests"} ${binaries:+-Dsonar.java.binaries="$binaries"} \
    "-Dsonar.java.libraries=/gradle-home/caches/modules-2/files-2.1/**/*.jar" \
    ${coverage:+-Dsonar.coverage.jacoco.xmlReportPaths="$coverage"} \
    -Dsonar.scm.exclusions.disabled=true -Dsonar.sourceEncoding=UTF-8
}

keyprop=${key:+-Dsonar.projectKey=$key}
echo "Анализ $src ($build, JDK $jdk${notests:+, без тестов}${key:+, проект $key}) ..."
marker=$(mktemp)

if [ "$build" = maven ]; then
  report=$src/target/sonar/report-task.txt
  goals="$JACOCO:prepare-agent verify $JACOCO:report"
  [ -n "$notests" ] && goals="verify -DskipTests"
  sonar="$SONAR_MAVEN:sonar"
  [ "$jdk" -lt $SCANNER_JDK ] && sonar=
  run "maven:$MAVEN_VERSION-eclipse-temurin-$jdk" mvn -B $goals $sonar $keyprop -Dmaven.test.failure.ignore=true || exit 1
  if [ -z "$sonar" ]; then
    echo; echo "Отправка в SonarQube (сканер на JDK $SCANNER_JDK) ..."
    run "maven:$MAVEN_VERSION-eclipse-temurin-$SCANNER_JDK" mvn -B "$SONAR_MAVEN:sonar" $keyprop || exit 1
  fi
else
  report=$src/build/sonar/report-task.txt
  SONAR_INIT_GRADLE=$(gradle_init)
  export SONAR_INIT_GRADLE
  # gradlew не запускаем: после checkout в Windows он с CRLF и в Linux не работает. Тот же wrapper - напрямую
  # через java, он скачает версию Gradle проекта. Нет wrapper - Gradle из образа. В образах gradle есть git и ssh:
  # многие сборки вызывают git при конфигурации.
  gradle=gradle
  [ -f "$src/gradle/wrapper/gradle-wrapper.jar" ] && gradle="java -cp gradle/wrapper/gradle-wrapper.jar org.gradle.wrapper.GradleWrapperMain"
  gv=$GRADLE_VERSION
  [ "$jdk" -lt 17 ] && gv=$GRADLE_VERSION_OLD_JDK
  tasks="test jacocoTestReport"
  [ -n "$notests" ] && tasks="classes testClasses"
  sonar=sonar
  [ "$jdk" -lt $SCANNER_JDK ] && sonar=
  if [ -n "$legacy" ]; then
    sonar=
    report=$src/.scannerwork/report-task.txt
  fi
  init='printf "%s" "$SONAR_INIT_GRADLE" > /tmp/sonar.init.gradle && exec "$@"'
  run "gradle:$gv-jdk$jdk" sh -c "$init" sh $gradle --no-daemon --init-script /tmp/sonar.init.gradle $tasks $sonar $keyprop || exit 1
  if [ -n "$legacy" ]; then
    scan_cli || exit 1
  elif [ -z "$sonar" ]; then
    echo; echo "Отправка в SonarQube (сканер на JDK $SCANNER_JDK, без пересборки) ..."
    run "gradle:$GRADLE_VERSION_OLD_JDK-jdk$SCANNER_JDK" sh -c "$init" sh $gradle --no-daemon \
      --init-script /tmp/sonar.init.gradle sonar -Dsonar.gradle.skipCompile=true $keyprop || exit 1
  fi
fi

# ссылку на отчёт сканер пишет в report-task.txt
if [ "$report" -nt "$marker" ]; then
  echo
  echo "Отчёт: $(sed -n 's/^dashboardUrl=//p' "$report")"
fi
rm -f "$marker"
