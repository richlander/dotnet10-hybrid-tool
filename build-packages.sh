#!/bin/bash
set -euo pipefail

# Build script for hybrid .NET tool packages
# Creates Native AOT packages for supported platforms + CoreCLR fallback

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="$SCRIPT_DIR/packages"
LINUX_X64_IMAGE="mcr.microsoft.com/dotnet-buildtools/prereqs:azurelinux-3.0-net10.0-cross-amd64"
LINUX_ARM64_IMAGE="mcr.microsoft.com/dotnet-buildtools/prereqs:azurelinux-3.0-net10.0-cross-arm64"
LINUX_SDK_DIR="$(mktemp -d)"
trap 'rm -rf "$LINUX_SDK_DIR"' EXIT

# Get git commit for SourceLink
GIT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "")

# Build args for official builds
PACK_ARGS="-p:OfficialBuild=true"
if [ -n "$GIT_COMMIT" ]; then
    PACK_ARGS="$PACK_ARGS -p:SourceRevisionId=$GIT_COMMIT"
fi

# The cross images provide the native toolchain and sysroots, but not the SDK.
docker run --rm --platform linux/amd64 \
    --user "$(id -u):$(id -g)" \
    -v "$LINUX_SDK_DIR:/dotnet" \
    -e HOME=/tmp \
    "$LINUX_X64_IMAGE" \
    sh -c 'curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh && sh /tmp/dotnet-install.sh --channel 10.0 --install-dir /dotnet'

# Clean function that handles root-owned files from docker
clean_build() {
    # Use docker to clean in case files are owned by root
    # Use find + rm to handle nested directories more reliably
    docker run --rm --platform linux/amd64 -v "$SCRIPT_DIR:/src" -w /src "$LINUX_X64_IMAGE" \
        bash -c 'find bin obj -mindepth 1 -delete 2>/dev/null || true; rm -rf bin obj'
}

# Clean previous builds
# Use find + rm to handle nested directories more reliably
docker run --rm --platform linux/amd64 -v "$SCRIPT_DIR:/src" -w /src "$LINUX_X64_IMAGE" \
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
docker run --rm --platform linux/amd64 \
    -v "$SCRIPT_DIR:/src" \
    -v "$LINUX_SDK_DIR:/host-dotnet:ro" \
    -w /src \
    -e ROOTFS_DIR=/crossrootfs/arm64 \
    -e DOTNET_ROOT=/host-dotnet \
    -e PATH="/host-dotnet:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    "$LINUX_ARM64_IMAGE" \
    sh -c "git config --global --add safe.directory /src && dotnet pack $PACK_ARGS -r linux-arm64 -p:SysRoot=\"\$ROOTFS_DIR\" -p:LinkerFlavor=lld -o /src/packages"

echo ""
echo "=== Step 4: Build linux-x64 with Native AOT (container + emulation) ==="
clean_build
docker run --rm --platform linux/amd64 \
    -v "$SCRIPT_DIR:/src" \
    -v "$LINUX_SDK_DIR:/host-dotnet:ro" \
    -w /src \
    -e ROOTFS_DIR=/crossrootfs/x64 \
    -e DOTNET_ROOT=/host-dotnet \
    -e PATH="/host-dotnet:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    "$LINUX_X64_IMAGE" \
    sh -c "git config --global --add safe.directory /src && dotnet pack $PACK_ARGS -r linux-x64 -p:SysRoot=\"\$ROOTFS_DIR\" -p:LinkerFlavor=lld -o /src/packages"

echo ""
echo "=== Step 5: Build any runtime with CoreCLR ==="
clean_build
dotnet pack $PACK_ARGS -r any -p:PublishAot=false -o "$PACKAGES_DIR"

echo ""
echo "=== Build complete ==="
echo ""
echo "Packages:"
ls -lh "$PACKAGES_DIR"
