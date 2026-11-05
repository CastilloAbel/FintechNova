# Build del frontend con Vite
FROM node:24-alpine3.22 AS build
WORKDIR /app

RUN apk upgrade --no-cache
COPY web/package*.json ./
RUN npm ci

COPY web/ .
RUN npm run build

# Servidor estático de producción; Traefik hará el enrutamiento y terminará TLS.
FROM node:24-alpine3.22 AS runtime
WORKDIR /app
    
RUN apk upgrade --no-cache \
    && npm install --global npm@12.2.2 \
    && npm cache clean --force

COPY web/runtime-package.json ./runtime/package.json
RUN npm install --prefix ./runtime --omit=dev --package-lock=false

COPY --from=build --chown=node:node /app/dist ./dist

ENV NODE_ENV=production
EXPOSE 8080
USER node

# -s habilita fallback a index.html para rutas de una SPA.
CMD ["./runtime/node_modules/.bin/serve", "-s", "dist", "-l", "8080"]
