#!/bin/bash
set -e

# Compile AL applications (Main App and Test App)
# Usage: ./compile-al-apps.sh

echo "=== Compiling AL Applications ==="

# Compile Main App
echo "Compiling The Library (main App)..."
COMPILE_START=$(date +%s.%N)

if al compile /project:"./App" /packagecachepath:".alpackages"; then
    COMPILE_END=$(date +%s.%N)
    COMPILE_DURATION=$(echo "$COMPILE_END - $COMPILE_START" | bc -l | sed 's/^\./0./')
    echo "COMPILE_DURATION=$COMPILE_DURATION" >> "$GITHUB_ENV"
    echo "Main app compilation took: $COMPILE_DURATION seconds"
    echo "Main app compilation successful"
else
    echo "Main app compilation failed with exit code: $?"
    exit 1
fi

# Copy compiled main app to .alpackages so TestApp can reference it
echo "Copying compiled main app to .alpackages..."
find ./App -maxdepth 1 -name "*.app" -type f -exec cp {} .alpackages/ \;
echo "Main app copied to .alpackages"

# Compile Test App
echo "Compiling The Library Tester (TestApp)..."
TEST_COMPILE_START=$(date +%s.%N)

if al compile /project:"./TestApp" /packagecachepath:".alpackages"; then
    TEST_COMPILE_END=$(date +%s.%N)
    TEST_COMPILE_DURATION=$(echo "$TEST_COMPILE_END - $TEST_COMPILE_START" | bc -l | sed 's/^\./0./')
    echo "TEST_COMPILE_DURATION=$TEST_COMPILE_DURATION" >> "$GITHUB_ENV"
    echo "Test app compilation took: $TEST_COMPILE_DURATION seconds"
    echo "Test app compilation successful"
else
    echo "Test app compilation failed with exit code: $?"
    exit 1
fi

# Post-compilation analysis
echo "Analyzing compiled apps..."
ANALYSIS_START=$(date +%s.%N)

# Analyze Main App
echo "Main App compiled files:"
find ./App -maxdepth 1 -type f -name "*.app" | while read file; do
    SIZE_BYTES=$(stat -c%s "$file" 2>/dev/null || echo "0")
    SIZE_KB=$(echo "scale=2; $SIZE_BYTES / 1024" | bc -l | sed 's/^\./0./')
    echo "  $(basename "$file") - ${SIZE_KB} KB"
done

# Count apps and calculate total size
APP_COUNT=$(find ./App -maxdepth 1 -type f -name "*.app" | wc -l)
if [ "$APP_COUNT" -gt 0 ]; then
    TOTAL_SIZE_BYTES=$(find ./App -maxdepth 1 -type f -name "*.app" -exec stat -c%s {} + 2>/dev/null | awk '{sum+=$1} END {print sum}' || echo "0")
    TOTAL_SIZE_KB=$(echo "scale=2; $TOTAL_SIZE_BYTES / 1024" | bc -l | sed 's/^\./0./')
    echo "APP_COUNT=$APP_COUNT" >> "$GITHUB_ENV"
    echo "TOTAL_APP_SIZE_KB=$TOTAL_SIZE_KB" >> "$GITHUB_ENV"
    echo "Total main app size: ${TOTAL_SIZE_KB} KB"
fi

# Analyze Test App
echo "Test App compiled files:"
TEST_APP_COUNT=$(find ./TestApp -maxdepth 1 -type f -name "*.app" | wc -l)
if [ "$TEST_APP_COUNT" -gt 0 ]; then
    TEST_SIZE_BYTES=$(find ./TestApp -maxdepth 1 -type f -name "*.app" -exec stat -c%s {} + 2>/dev/null | awk '{sum+=$1} END {print sum}' || echo "0")
    TEST_SIZE_KB=$(echo "scale=2; $TEST_SIZE_BYTES / 1024" | bc -l | sed 's/^\./0./')
    echo "TEST_APP_COUNT=$TEST_APP_COUNT" >> "$GITHUB_ENV"
    echo "TOTAL_TEST_SIZE_KB=$TEST_SIZE_KB" >> "$GITHUB_ENV"
    echo "Total test app size: ${TEST_SIZE_KB} KB"
fi

ANALYSIS_END=$(date +%s.%N)
ANALYSIS_DURATION=$(echo "$ANALYSIS_END - $ANALYSIS_START" | bc -l | sed 's/^\./0./')
echo "POST_COMPILE_ANALYSIS_DURATION=$ANALYSIS_DURATION" >> "$GITHUB_ENV"
echo "Post-compilation analysis: $ANALYSIS_DURATION seconds"
