FROM node:24-bookworm-slim

ENV NODE_ENV=production HOST=0.0.0.0 PORT=3000 DATA_DIR=/data
WORKDIR /app

COPY package.json ./
COPY public/ ./public/
COPY lib/ ./lib/
COPY server/ ./server/
COPY database/ ./database/

RUN mkdir -p /data && chown node:node /data
USER node
EXPOSE 3000
CMD ["node", "server/index.mjs"]
