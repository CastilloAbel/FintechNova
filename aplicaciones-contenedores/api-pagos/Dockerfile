FROM node:20-alpine3.22

WORKDIR /app

RUN apk upgrade --no-cache
COPY package.json package-lock.json ./

RUN npm ci --omit=dev \
	&& npm install --global npm@latest \
	&& npm cache clean --force

COPY --chown=node:node src/ ./src/

EXPOSE 8080

USER node

CMD ["npm", "start"]