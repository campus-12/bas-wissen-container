# Stage 1: Build the frontend
FROM node:22.11.0-alpine3.20 as frontend-build
RUN npm install -g pnpm
WORKDIR /app
COPY ./app/bas-pruefungsgenerator-web/package*.json ./
COPY ./app/bas-pruefungsgenerator-web/.npmrc ./
RUN --mount=type=secret,id=GITHUB_PACKAGE_REGISTRY_TOKEN export GITHUB_PACKAGE_REGISTRY_TOKEN=$(cat /run/secrets/GITHUB_PACKAGE_REGISTRY_TOKEN) && pnpm install
COPY ./app/bas-pruefungsgenerator-web/ ./
COPY ./environment/.env.web ./.env
RUN pnpm run build

# Stage 2: Build the backend
FROM node:22.11.0-alpine3.20 as backend-build
RUN npm install -g pnpm
WORKDIR /app
COPY ./app/bas-pruefungsgenerator-backend/package*.json ./
COPY ./app/bas-pruefungsgenerator-backend/.npmrc ./
RUN pnpm install
COPY ./app/bas-pruefungsgenerator-backend/ .
RUN pnpm run build

# Stage 3: Production environment
# Intended directory structure:
# /
# |-- /data
# |   |-- /templates
# |-- /app
#     |-- /backend
#     |-- /web
FROM node:22.11.0-alpine3.20
ARG BACKEND_PORT=3000
ENV BACKEND_PORT=$BACKEND_PORT
ARG DATA_PATH=data

# Install Caddy
RUN apk add --no-cache caddy

# Copy data and app
WORKDIR /
COPY ./data $DATA_PATH
VOLUME $DATA_PATH
#  Root path for data from the perspective of the backend
ENV DATA_PATH=../../$DATA_PATH

# Copy built results
WORKDIR /app
COPY --from=backend-build /app/dist/src ./backend
COPY --from=backend-build /app/node_modules ./backend/node_modules
COPY ./environment/.env.backend ./backend/.env
COPY --from=frontend-build /app/dist ./web

# Configure Caddy
COPY <<EOF /etc/caddy/Caddyfile
:80 {
    # Backend API
    reverse_proxy /api/* localhost:3000

    # Frontend
    root * /app/web
    file_server
    
    # SPA fallback
    try_files {path} /index.html
}
EOF

# Create startup script
COPY <<'EOF' /start.sh
#!/bin/sh
# Start backend in background
cd /app/backend
NODE_ENV=production node main.js &

# Start Caddy in foreground
caddy run --config /etc/caddy/Caddyfile
EOF

RUN chmod +x /start.sh

ENV NODE_ENV=production
EXPOSE 80
CMD ["/start.sh"]