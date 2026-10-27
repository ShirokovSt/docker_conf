# Агент TeamCity для devstack: официальный агент 2026.1.1 + JDK 8/11/17/21 и Maven 3.6.3 / 3.9 -
# с привычными именами env.JDK_* и свойствами teamcity.tool.maven*.
# Собирается только через teamcity\build-image.bat и только под НОВЫМ тегом: собранные теги не меняются.
# Docker внутри сборок - сокет Docker Desktop (монтируется в teamcity/docker-compose.yml), свой dockerd не нужен.

FROM eclipse-temurin:8-jdk AS jdk8
FROM eclipse-temurin:11-jdk AS jdk11
FROM eclipse-temurin:17-jdk AS jdk17

FROM jetbrains/teamcity-agent:2026.1.1

USER root

# JDK 21 уже есть в базовом образе (/opt/java/openjdk, на нём работает сам агент) - на него только ссылка
COPY --from=jdk8  /opt/java/openjdk /opt/jdk/8
COPY --from=jdk11 /opt/java/openjdk /opt/jdk/11
COPY --from=jdk17 /opt/java/openjdk /opt/jdk/17
RUN ln -s /opt/java/openjdk /opt/jdk/21

# Имена переменных - как у типового Linux-агента: готовые конфигурации (target.jdk.home=%env.JDK_11_0_x64%,
# требование exists env.JDK_11) работают без правок. JAVA_HOME и JDK_HOME = JDK 21.
ENV JDK_1_8=/opt/jdk/8 \
    JDK_1_8_x64=/opt/jdk/8 \
    JDK_18=/opt/jdk/8 \
    JDK_18_x64=/opt/jdk/8 \
    JDK_11=/opt/jdk/11 \
    JDK_11_x64=/opt/jdk/11 \
    JDK_11_0=/opt/jdk/11 \
    JDK_11_0_x64=/opt/jdk/11 \
    JDK_17=/opt/jdk/17 \
    JDK_17_x64=/opt/jdk/17 \
    JDK_17_0=/opt/jdk/17 \
    JDK_17_0_x64=/opt/jdk/17 \
    JDK_21=/opt/jdk/21 \
    JDK_21_x64=/opt/jdk/21 \
    JDK_21_0=/opt/jdk/21 \
    JDK_21_0_x64=/opt/jdk/21

# Maven 3.6.3 и 3.9: в сборках - %teamcity.tool.maven.3.6.3% / %teamcity.tool.maven3_9% ,
# в командной строке - mvn (3.9). Встроенный Maven раннера TeamCity тоже доступен.
ARG MAVEN_36_VERSION=3.6.3
ARG MAVEN_39_VERSION=3.9.16
RUN set -e; \
    for v in ${MAVEN_36_VERSION} ${MAVEN_39_VERSION}; do \
      mkdir -p /opt/maven/$v; \
      curl -fsSL https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/$v/apache-maven-$v-bin.tar.gz \
        | tar -xz -C /opt/maven/$v --strip-components=1; \
    done; \
    ln -s /opt/maven/${MAVEN_39_VERSION}/bin/mvn /usr/local/bin/mvn; \
    printf '\n# devstack: Maven, teamcity.tool.*\nteamcity.tool.maven.3.6.3=/opt/maven/%s\nteamcity.tool.maven3_9=/opt/maven/%s\n' \
      ${MAVEN_36_VERSION} ${MAVEN_39_VERSION} >> /opt/buildagent/conf/buildAgent.dist.properties

# Корневые сертификаты (необязательно): *.crt из папки certs - в системное хранилище
# и в cacerts всех JDK. Пустая папка - шаг ничего не делает.
COPY certs/ /tmp/certs/
RUN set -e; \
    for c in /tmp/certs/*.crt; do \
      [ -f "$c" ] || continue; \
      alias="devstack-$(basename "$c" .crt)"; \
      cp "$c" /usr/local/share/ca-certificates/; \
      for ks in /opt/jdk/8/jre/lib/security/cacerts /opt/jdk/11/lib/security/cacerts \
                /opt/jdk/17/lib/security/cacerts /opt/java/openjdk/lib/security/cacerts; do \
        /opt/java/openjdk/bin/keytool -importcert -noprompt -storepass changeit -keystore "$ks" -alias "$alias" -file "$c"; \
      done; \
    done; \
    update-ca-certificates; \
    rm -rf /tmp/certs

# Сборки из локальной папки ПК: devstack-sync <папка> - инкрементальная синхронизация папки в рабочую
# папку сборки через rsync (используется рецептом TeamCity "Локальная папка", см. teamcity/README.md).
RUN apt-get update \
    && apt-get install -y --no-install-recommends rsync \
    && rm -rf /var/lib/apt/lists/*
COPY devstack-sync /usr/local/bin/devstack-sync
RUN chmod 755 /usr/local/bin/devstack-sync

USER buildagent
