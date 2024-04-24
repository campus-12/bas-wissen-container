# # Stage 1: Build the frontend
FROM node:20.12 as frontend-build
WORKDIR /app
COPY ./bas-pruefungsgenerator-web/package*.json ./
COPY ./bas-pruefungsgenerator-web/.npmrc ./
ARG GITHUB_PACKAGE_REGISTRY_TOKEN
RUN npm install --silent
COPY ./bas-pruefungsgenerator-web/ .
RUN npm run build

# Stage 2: Build the backend
FROM node:20.12-alpine as backend-build
WORKDIR /app
COPY ./bas-pruefungsgenerator-backend/package*.json ./
COPY ./bas-pruefungsgenerator-backend/.npmrc ./
RUN npm install --silent
COPY ./bas-pruefungsgenerator-backend/ .
RUN npm run build

# Stage 3: Production environment
FROM node:20.12-alpine
ARG BACKEND_PORT=3000
WORKDIR /app

# Copy built backend
COPY --from=backend-build /app/dist ./backend
COPY --from=backend-build /app/node_modules ./backend/node_modules

# Copy built frontend
COPY --from=frontend-build /app/dist ./frontend/dist

# Setup environment variables, ports, and start command
ENV NODE_ENV=production
ENV BACKEND_PORT=$BACKEND_PORT
ENV FRONTEND_ROOT_PATH=/app/frontend/dist

EXPOSE $BACKEND_PORT
CMD ["node", "./backend/main.js"]