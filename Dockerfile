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
RUN corepack enable && corepack prepare pnpm@^9.x --activate
WORKDIR /app
COPY ./app/BASinteractiveMoviesFrontend/package*.json ./
COPY ./app/BASinteractiveMoviesFrontend/pnpm-lock.yaml ./
RUN pnpm i --frozen-lockfile
COPY ./app/BASinteractiveMoviesFrontend/ ./
COPY ./environment/.env.web ./.env
RUN pnpm build

# Stage 2: Build the backend
FROM node:22-alpine AS backend-build
RUN corepack enable && corepack prepare pnpm@^9.x --activate
WORKDIR /app
COPY ./app/BASinteractiveMoviesBackend/package*.json ./
COPY ./app/BASinteractiveMoviesBackend/pnpm-lock.yaml ./
RUN pnpm i --frozen-lockfile
COPY ./app/BASinteractiveMoviesBackend/ .
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

# Install Caddy, wget for health checks, and ffmpeg for video processing
RUN apk add --no-cache caddy wget ffmpeg

# Copy built results
WORKDIR /app
COPY --from=backend-build /app/dist ./backend/dist
COPY --from=backend-build /app/node_modules ./backend/node_modules
COPY --from=backend-build /app/package.json ./backend/package.json
COPY --from=frontend-build /app/dist ./web

# Copy configuration files
COPY Caddyfile /etc/caddy/Caddyfile
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Create data directories for video storage
RUN mkdir -p /data/videos

ENV NODE_ENV=production
EXPOSE 80
CMD ["/start.sh"]
