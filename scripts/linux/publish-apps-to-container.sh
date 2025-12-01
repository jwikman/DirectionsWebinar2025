#!/bin/bash
set -e

# Publish AL apps to BC container via API
# Usage: ./publish-apps-to-container.sh [BASE_URL] [USERNAME] [PASSWORD]

BASE_URL="${1:-http://localhost:7049}"
USERNAME="${2:-admin}"
PASSWORD="${3:-Admin123!}"

echo "=== Publishing Apps to BC Container ==="

# Publish Main App
echo "Publishing The Library (main app) to BC container..."
PUBLISH_START=$(date +%s.%N)

# Find the main app file
APP_FILE=$(find ./App -maxdepth 1 -name "*.app" -type f | head -n 1)
if [ -z "$APP_FILE" ]; then
    echo "ERROR: No main app file found for publishing"
    exit 1
fi

echo "Publishing app file: $APP_FILE"

# Publish extension to BC container using API
curl -u "$USERNAME:$PASSWORD" \
     -F "file=@$APP_FILE" \
     "$BASE_URL/BC/dev/apps?tenant=default&SchemaUpdateMode=synchronize&DependencyPublishingOption=default"

PUBLISH_END=$(date +%s.%N)
PUBLISH_DURATION=$(echo "$PUBLISH_END - $PUBLISH_START" | bc -l | sed 's/^\./0./')
echo "PUBLISH_DURATION=$PUBLISH_DURATION" >> "$GITHUB_ENV"
echo "Main app publishing took: $PUBLISH_DURATION seconds"

# Publish Test App
echo "Publishing The Library Tester (test app) to BC container..."
TEST_PUBLISH_START=$(date +%s.%N)

# Find the test app file (excluding .dep.app files)
TEST_APP_FILE=$(find ./TestApp -maxdepth 1 -name "*.app" -type f ! -name "*.dep.app" | head -n 1)
if [ -z "$TEST_APP_FILE" ]; then
    echo "ERROR: No test app file found for publishing"
    exit 1
fi

echo "Publishing test app file: $TEST_APP_FILE"

# Publish extension to BC container using API
curl -u "$USERNAME:$PASSWORD" \
     -F "file=@$TEST_APP_FILE" \
     "$BASE_URL/BC/dev/apps?tenant=default&SchemaUpdateMode=synchronize&DependencyPublishingOption=default"

TEST_PUBLISH_END=$(date +%s.%N)
TEST_PUBLISH_DURATION=$(echo "$TEST_PUBLISH_END - $TEST_PUBLISH_START" | bc -l | sed 's/^\./0./')
echo "TEST_PUBLISH_DURATION=$TEST_PUBLISH_DURATION" >> "$GITHUB_ENV"
echo "Test app publishing took: $TEST_PUBLISH_DURATION seconds"

echo "✓ All apps published successfully"
