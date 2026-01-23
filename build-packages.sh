#!/bin/bash
set -euo pipefail

# Build script for hybrid .NET tool packages
# Creates Native AOT packages for supported platforms + CoreCLR fallback

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="$SCRIPT_DIR/packages"
AOT_IMAGE="mcr.microsoft.com/dotnet/sdk:10.0-noble-aot"

# Get git commit for SourceLink
GIT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "")

# Build args for official builds
PACK_ARGS="-p:OfficialBuild=true"
if [ -n "$GIT_COMMIT" ]; then
    PACK_ARGS="$PACK_ARGS -p:SourceRevisionId=$GIT_COMMIT"
fi

# Clean function that handles root-owned files from docker
clean_build() {
    # Use docker to clean in case files are owned by root
    # Use find + rm to handle nested directories more reliably
    docker run --rm -v "$SCRIPT_DIR:/src" -w /src $AOT_IMAGE \
        bash -c 'find bin obj -mindepth 1 -delete 2>/dev/null || true; rm -rf bin obj'
}

# Clean previous builds
# Use find + rm to handle nested directories more reliably
docker run --rm -v "$SCRIPT_DIR:/src" -w /src $AOT_IMAGE \
    bash -c 'find bin obj packages -mindepth 1 -delete 2>/dev/null || true; rm -rf bin obj packages'
mkdir -p "$PACKAGES_DIR"

echo "=== Step 1: Create pointer package ==="
echo "Git commit: ${GIT_COMMIT:-not available}"
# With ToolPackageRuntimeIdentifiers, this only creates the pointer package
dotnet pack $PACK_ARGS -o "$PACKAGES_DIR"

echo ""
echo "=== Step 2: Build osx-arm64 with Native AOT ==="
clean_build
dotnet pack $PACK_ARGS -r osx-arm64 -o "$PACKAGES_DIR"

echo ""
echo "=== Step 3: Build linux-arm64 with Native AOT (container) ==="
clean_build
docker run --rm \
    -v "$SCRIPT_DIR:/src" \
    -w /src \
    $AOT_IMAGE \
    dotnet pack $PACK_ARGS -r linux-arm64 -o /src/packages

echo ""
echo "=== Step 4: Build linux-x64 with Native AOT (container + emulation) ==="
clean_build
docker run --rm --platform linux/amd64 \
    -v "$SCRIPT_DIR:/src" \
    -w /src \
    $AOT_IMAGE \
    dotnet pack $PACK_ARGS -r linux-x64 -o /src/packages

echo ""
echo "=== Step 5: Build any runtime with CoreCLR ==="
clean_build
dotnet pack $PACK_ARGS -r any -p:PublishAot=false -o "$PACKAGES_DIR"

echo ""
echo "=== Build complete ==="
echo ""
echo "Packages:"
ls -lh "$PACKAGES_DIR"
