# Current known vulnerabilities in base image:
#
# CVE-2025-64756:
# - Affects: npm / glob / 10.4.5
# - And so node:22.21.1-alpine
# - And so node:22-alpine (as of 2025-12-10)
#
# Risk: Low (Low severity, requires attacker to have write access to project files)


# Stage 1: Build the frontend
FROM node:22-alpine AS frontend-build
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
FROM node:22-alpine AS backend-build
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
FROM node:22-alpine
ARG BACKEND_PORT=3000
ENV BACKEND_PORT=$BACKEND_PORT
ARG DATA_PATH=data

# Install Caddy and wget for health checks
RUN apk add --no-cache caddy wget

# Copy built results
WORKDIR /app
COPY --from=backend-build /app/dist ./backend/dist
COPY --from=backend-build /app/node_modules ./backend/node_modules
COPY --from=backend-build /app/package.json ./backend/package.json
COPY --from=backend-build /app/tsconfig.json ./backend/tsconfig.json
COPY --from=backend-build /app/templates ./backend/templates
COPY ./environment/.env.backend ./backend/.env
COPY --from=frontend-build /app/dist ./web

# Copy configuration files
COPY Caddyfile /etc/caddy/Caddyfile
COPY start.sh /start.sh
RUN chmod +x /start.sh

ENV NODE_ENV=production
EXPOSE 80
CMD ["/start.sh"]
