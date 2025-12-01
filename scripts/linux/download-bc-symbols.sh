#!/bin/bash
set -e

# Download Business Central symbol packages from Microsoft NuGet feeds
# Usage: ./download-bc-symbols.sh <BC_VERSION> <PLATFORM_VERSION>

BC_VERSION="${1:-27.1.41698.41776}"
PLATFORM_VERSION="${2:-27.0.41766}"

echo "Downloading Business Central symbol packages from Microsoft feed..."
DOWNLOAD_START=$(date +%s.%N)

# Microsoft BC Symbols NuGet feeds (two different feeds for different package types)
BC_FEED_SYMBOLS="https://dynamicssmb2.pkgs.visualstudio.com/571e802d-b44b-45fc-bd41-4cfddec73b44/_packaging/b656b10c-3de0-440c-900c-bc2e4e86d84c/nuget/v3/flat2"
BC_FEED_MAIN="https://dynamicssmb2.pkgs.visualstudio.com/571e802d-b44b-45fc-bd41-4cfddec73b44/_packaging/9c5cd71f-8d45-40bf-8fde-4ac4d924365a/nuget/v3/flat2"

# Create directories
mkdir -p .alpackages
mkdir -p temp_packages

echo "Downloading Microsoft.SystemApplication..."
curl -L -s -o "temp_packages/microsoft.systemapplication.nupkg" \
    "$BC_FEED_MAIN/microsoft.systemapplication.63ca2fa4-4f03-4f2b-a480-172fef340d3f/$BC_VERSION/microsoft.systemapplication.63ca2fa4-4f03-4f2b-a480-172fef340d3f.$BC_VERSION.nupkg" || echo "Failed to download System Application"

echo "Downloading Microsoft.BaseApplication..."
curl -L -s -o "temp_packages/microsoft.baseapplication.nupkg" \
    "$BC_FEED_MAIN/microsoft.baseapplication.437dbf0e-84ff-417a-965d-ed2bb9650972/$BC_VERSION/microsoft.baseapplication.437dbf0e-84ff-417a-965d-ed2bb9650972.$BC_VERSION.nupkg" || echo "Failed to download Base Application"

echo "Downloading Microsoft.Application.symbols..."
curl -L -s -o "temp_packages/microsoft.application.symbols.nupkg" \
    "$BC_FEED_SYMBOLS/microsoft.application.symbols/$BC_VERSION/microsoft.application.symbols.$BC_VERSION.nupkg" || echo "Failed to download Application"

# Second-level dependencies
echo "Downloading Microsoft.BusinessFoundation (second-level dependency)..."
curl -L -s -o "temp_packages/microsoft.businessfoundation.nupkg" \
    "$BC_FEED_MAIN/microsoft.businessfoundation.f3552374-a1f2-4356-848e-196002525837/$BC_VERSION/microsoft.businessfoundation.f3552374-a1f2-4356-848e-196002525837.$BC_VERSION.nupkg" || echo "Failed to download Business Foundation"

# The actual System package (not SystemApplication)
echo "Downloading Microsoft.Platform v$PLATFORM_VERSION (System dependency)..."
curl -L -s -o "temp_packages/microsoft.platform.nupkg" \
    "$BC_FEED_MAIN/microsoft.platform/$PLATFORM_VERSION/microsoft.platform.$PLATFORM_VERSION.nupkg" || echo "Failed to download Platform (System)"

# Test dependencies
echo "Downloading Microsoft.Any.symbols (test dependency)..."
curl -L -s -o "temp_packages/microsoft.any.symbols.nupkg" \
    "$BC_FEED_SYMBOLS/microsoft.any.symbols.e7320ebb-08b3-4406-b1ec-b4927d3e280b/$BC_VERSION/microsoft.any.symbols.e7320ebb-08b3-4406-b1ec-b4927d3e280b.$BC_VERSION.nupkg" || echo "Failed to download Any"

echo "Downloading Microsoft.LibraryAssert.symbols (test dependency)..."
curl -L -s -o "temp_packages/microsoft.libraryassert.symbols.nupkg" \
    "$BC_FEED_SYMBOLS/microsoft.libraryassert.symbols.dd0be2ea-f733-4d65-bb34-a28f4624fb14/$BC_VERSION/microsoft.libraryassert.symbols.dd0be2ea-f733-4d65-bb34-a28f4624fb14.$BC_VERSION.nupkg" || echo "Failed to download Library Assert"

echo "Downloading Microsoft.TestRunner.symbols (test dependency)..."
curl -L -s -o "temp_packages/microsoft.testrunner.symbols.nupkg" \
    "$BC_FEED_SYMBOLS/microsoft.testrunner.symbols.23de40a6-dfe8-4f80-80db-d70f83ce8caf/$BC_VERSION/microsoft.testrunner.symbols.23de40a6-dfe8-4f80-80db-d70f83ce8caf.$BC_VERSION.nupkg" || echo "Failed to download Test Runner"

echo "Downloading Microsoft.LibraryVariableStorage.symbols (test dependency)..."
curl -L -s -o "temp_packages/microsoft.libraryvariablestorage.symbols.nupkg" \
    "$BC_FEED_SYMBOLS/microsoft.libraryvariablestorage.symbols.5095f467-0a01-4b99-99d1-9ff1237d286f/$BC_VERSION/microsoft.libraryvariablestorage.symbols.5095f467-0a01-4b99-99d1-9ff1237d286f.$BC_VERSION.nupkg" || echo "Failed to download Library Variable Storage"

# Extract .nupkg files (which are zip files)
mkdir -p temp_packages/extracted
for nupkg in temp_packages/*.nupkg; do
    if [ -f "$nupkg" ] && [ -s "$nupkg" ]; then
        echo "Extracting $(basename "$nupkg")..."
        mkdir -p "temp_packages/extracted/$(basename "$nupkg" .nupkg)"
        unzip -q "$nupkg" -d "temp_packages/extracted/$(basename "$nupkg" .nupkg)" || echo "Failed to extract $nupkg"
    else
        echo "Skipping empty or missing file: $(basename "$nupkg")"
    fi
done

# Extract .app files from downloaded packages
find temp_packages -name "*.app" -type f -exec cp {} .alpackages/ \;

# Clean up temporary files
rm -rf temp_packages

DOWNLOAD_END=$(date +%s.%N)
DOWNLOAD_DURATION=$(echo "$DOWNLOAD_END - $DOWNLOAD_START" | bc -l | sed 's/^\./0./')
echo "SYSTEM_DOWNLOAD_DURATION=$DOWNLOAD_DURATION" >> "$GITHUB_ENV"
echo "SYSTEM_EXTRACT_DURATION=0" >> "$GITHUB_ENV"
echo "BC symbols download took: $DOWNLOAD_DURATION seconds"

# List downloaded symbols
echo "Downloaded symbol packages:"
ls -la .alpackages/
