# Build del frontend con Vite
FROM node:24-alpine3.21 AS build
WORKDIR /app

COPY web/package*.json ./
RUN npm ci

COPY web . .
RUN npm run build

# Servidor estático de producción; Traefik hará el enrutamiento y terminará TLS.
FROM node:24-alpine3.21 AS runtime
WORKDIR /app
    
RUN npm install --global serve@14.2.4 \
    && npm cache clean --force

COPY --from=build --chown=node:node /app/dist ./dist

ENV NODE_ENV=production
EXPOSE 8080
USER node

# -s habilita fallback a index.html para rutas de una SPA.
CMD ["serve", "-s", "dist", "-l", "8080"]
