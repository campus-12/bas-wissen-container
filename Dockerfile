# Stage 1: Build the frontend
FROM node:22.20.0-alpine3.22 AS frontend-build
#RUN npm install -g pnpm
RUN corepack enable && corepack prepare pnpm@^9.x --activate
WORKDIR /app
COPY ./app/bas-pruefungsgenerator-web/package*.json ./
COPY ./app/bas-pruefungsgenerator-web/.npmrc ./
COPY ./app/bas-pruefungsgenerator-web/pnpm-lock.yaml ./
RUN --mount=type=secret,id=GITHUB_PACKAGE_REGISTRY_TOKEN export GITHUB_PACKAGE_REGISTRY_TOKEN=$(cat /run/secrets/GITHUB_PACKAGE_REGISTRY_TOKEN) && pnpm i --frozen-lockfile
COPY ./app/bas-pruefungsgenerator-web/ ./
COPY ./environment/.env.web ./.env
RUN pnpm build

# Stage 2: Build the backend
FROM node:22.20.0-alpine3.22 AS backend-build
RUN corepack enable && corepack prepare pnpm@^9.x --activate
WORKDIR /app
COPY ./app/bas-pruefungsgenerator-backend/package*.json ./
COPY ./app/bas-pruefungsgenerator-backend/.npmrc ./
COPY ./app/bas-pruefungsgenerator-backend/pnpm-lock.yaml ./
RUN pnpm i --frozen-lockfile
COPY ./app/bas-pruefungsgenerator-backend/ .
RUN pnpm build

# Stage 3: Production environment
# Intended directory structure:
# /
# |-- /data
# |   |-- /templates
# |-- /app
#     |-- /backend
#     |-- /web
FROM node:22.20.0-alpine3.22
ARG BACKEND_PORT=3000
ENV BACKEND_PORT=$BACKEND_PORT
ARG DATA_PATH=data

# Install Caddy
RUN apk add --no-cache caddy

# Copy data and app
WORKDIR /
COPY ./data $DATA_PATH
VOLUME $DATA_PATH
ENV DATA_PATH=../../$DATA_PATH

# Copy built results
WORKDIR /app
COPY --from=backend-build /app/dist/src ./backend
COPY --from=backend-build /app/node_modules ./backend/node_modules
COPY --from=backend-build /app/package.json ./backend/package.json
COPY ./environment/.env.backend ./backend/.env
COPY --from=frontend-build /app/dist ./web

# Copy configuration files
COPY Caddyfile /etc/caddy/Caddyfile
COPY start.sh /start.sh
RUN chmod +x /start.sh

RUN corepack enable && corepack prepare pnpm@^9.x --activate

ENV NODE_ENV=production
EXPOSE 80
CMD ["/start.sh"]
