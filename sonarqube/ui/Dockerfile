# Страница анализа SonarQube для docker_conf (server.js + public/index.html) и настройка SonarQube (setup.sh).
# Собирается compose при запуске (pull_policy: build); зависимости - строго по package-lock.json.
# docker-cli - запуск сборок проектов (analyze.sh), postgresql-client и openssl - пароль администратора (setup.sh).
FROM node:22.22-alpine

RUN apk add --no-cache docker-cli postgresql-client openssl curl

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund && npm cache clean --force
COPY server.js entrypoint.sh setup.sh analyze.sh ./
COPY public ./public

ENV NODE_ENV=production PORT=8080
EXPOSE 8080
# root: нужен доступ к docker.sock, чтобы запускать контейнеры сборки
CMD ["sh", "/app/entrypoint.sh"]
