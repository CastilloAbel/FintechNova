FROM node:20-alpine

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci --omit=dev

COPY --chown=node:node src/ ./src/

EXPOSE 8080

USER node

CMD ["npm", "start"]