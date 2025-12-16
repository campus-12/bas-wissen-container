#!/bin/sh
set -e

echo "Starting BAS Wissen..."

# Start backend in background
echo "Starting backend on port 3000..."
cd /app/backend
node dist/main.js &
BACKEND_PID=$!

# Wait for backend to be ready
echo "Waiting for backend to start..."
sleep 5

# Check if backend is running
if ! kill -0 $BACKEND_PID 2>/dev/null; then
    echo "ERROR: Backend failed to start!"
    exit 1
fi

# Test if backend is actually responding
echo "Testing backend connectivity..."
max_attempts=10
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if wget -q --spider http://127.0.0.1:3000/ 2>/dev/null; then
        echo "Backend is responding!"
        break
    fi
    attempt=$((attempt + 1))
    echo "Attempt $attempt/$max_attempts: Backend not ready yet..."
    sleep 1
done

if [ $attempt -eq $max_attempts ]; then
    echo "WARNING: Backend might not be fully ready"
fi

echo "Backend started successfully (PID: $BACKEND_PID)"

# Start Caddy in foreground
echo "Starting Caddy reverse proxy..."
exec caddy run --config /etc/caddy/Caddyfile
