#!/bin/sh
set -e

echo "Starting BAS Prüfungsgenerator..."

# Start backend in background
echo "Starting backend on port 3000..."
cd /app/backend
NODE_ENV=production node main.js &
BACKEND_PID=$!

# Wait for backend to be ready
echo "Waiting for backend to start..."
sleep 3

# Check if backend is running
if ! kill -0 $BACKEND_PID 2>/dev/null; then
    echo "ERROR: Backend failed to start!"
    exit 1
fi

echo "Backend started successfully (PID: $BACKEND_PID)"

# Start Caddy in foreground
echo "Starting Caddy reverse proxy..."
exec caddy run --config /etc/caddy/Caddyfile
