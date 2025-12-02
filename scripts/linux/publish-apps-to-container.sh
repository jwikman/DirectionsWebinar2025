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

# Find the main app file
APP_FILE=$(find ./App -maxdepth 1 -name "*.app" -type f | head -n 1)
if [ -z "$APP_FILE" ]; then
    echo "ERROR: No main app file found for publishing"
    exit 1
fi

echo "Publishing app file: $APP_FILE"

# Publish extension to BC container using API
HTTP_CODE=$(curl -u "$USERNAME:$PASSWORD" \
     -F "file=@$APP_FILE" \
     -w "%{http_code}" \
     -o /tmp/publish_response.txt \
     "$BASE_URL/BC/dev/apps?tenant=default&SchemaUpdateMode=synchronize&DependencyPublishingOption=default")

if [ "$HTTP_CODE" -ge 400 ]; then
    echo "ERROR: Failed to publish main app (HTTP $HTTP_CODE)"
    cat /tmp/publish_response.txt
    exit 1
fi

# Publish Test App
echo "Publishing The Library Tester (test app) to BC container..."

# Find the test app file (excluding .dep.app files)
TEST_APP_FILE=$(find ./TestApp -maxdepth 1 -name "*.app" -type f ! -name "*.dep.app" | head -n 1)
if [ -z "$TEST_APP_FILE" ]; then
    echo "ERROR: No test app file found for publishing"
    exit 1
fi

echo "Publishing test app file: $TEST_APP_FILE"

# Publish extension to BC container using API
HTTP_CODE=$(curl -u "$USERNAME:$PASSWORD" \
     -F "file=@$TEST_APP_FILE" \
     -w "%{http_code}" \
     -o /tmp/publish_response.txt \
     "$BASE_URL/BC/dev/apps?tenant=default&SchemaUpdateMode=synchronize&DependencyPublishingOption=default")

if [ "$HTTP_CODE" -ge 400 ]; then
    echo "ERROR: Failed to publish test app (HTTP $HTTP_CODE)"
    cat /tmp/publish_response.txt
    exit 1
fi

echo "✓ All apps published successfully"