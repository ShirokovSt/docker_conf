# Веб-интерфейс Cassandra для docker_conf (server.js + public/index.html).
# Собирается compose при первом запуске (cassandra\start.bat); зависимости - строго по package-lock.json.
FROM node:22.22-alpine

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund && npm cache clean --force
COPY server.js ./
COPY public ./public

ENV NODE_ENV=production PORT=8080
EXPOSE 8080
USER node
CMD ["node", "server.js"]
