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

# Copy initial data like templates and configure data path
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
ENV FRONTEND_ROOT_PATH=/app/web

# Start the backend
ENV NODE_ENV=production
EXPOSE $BACKEND_PORT
WORKDIR /app/backend
CMD ["node", "main.js"]