#!/bin/bash
set -e

# Start Business Central container and wait for it to become healthy
# Usage: ./start-bc-container.sh [MAX_WAIT_SECONDS]

MAX_WAIT="${1:-1200}"  # Default: 20 minutes

echo "Starting Business Central container..."
CONTAINER_START_TIME=$(date +%s.%N)
cd bcdev-temp

# Start the container
docker compose up -d

# Wait for container to become healthy (can take up to 10 minutes)
echo "Waiting for BC container to become healthy (this can take up to 10 minutes)..."
CONTAINER_NAME=$(docker compose ps -q | head -n 1)
ELAPSED=0
HEALTH_STATUS=""
PREV_HEALTH_STATUS=""

while [ $ELAPSED -lt $MAX_WAIT ]; do
    HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "unknown")

    if [ "$HEALTH_STATUS" = "healthy" ]; then
        echo "✓ BC container is healthy and ready"
        break
    fi

    # Check if container became unhealthy (was starting, now unhealthy)
    if [ "$HEALTH_STATUS" = "unhealthy" ] && [ "$PREV_HEALTH_STATUS" != "unhealthy" ]; then
        echo "⚠ Container became unhealthy - printing logs for investigation:"
        docker compose ps
        docker compose logs --tail=100
    fi

    echo "Container status: $HEALTH_STATUS (waited ${ELAPSED}s / ${MAX_WAIT}s)"
    PREV_HEALTH_STATUS="$HEALTH_STATUS"
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

# Final health check after loop completes (in case timeout was reached while healthy)
HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "unknown")
if [ "$HEALTH_STATUS" != "healthy" ]; then
    echo "ERROR: Container did not become healthy within $MAX_WAIT seconds"
    echo "Final status: $HEALTH_STATUS"
    echo "Printing full container logs:"
    docker compose ps
    docker compose logs
    exit 1
fi

# Check container status
docker compose ps
docker compose logs

CONTAINER_START_END=$(date +%s.%N)
CONTAINER_START_DURATION=$(echo "$CONTAINER_START_END - $CONTAINER_START_TIME" | bc -l | sed 's/^\./0./')
echo "CONTAINER_START_DURATION=$CONTAINER_START_DURATION" >> "$GITHUB_ENV"
echo "Container startup took: $CONTAINER_START_DURATION seconds"
cd ..
