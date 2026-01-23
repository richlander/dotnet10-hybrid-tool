# dotnet10-hybrid-tool

A demo .NET tool showing hybrid RID-specific packaging with Native AOT for select platforms and CoreCLR fallback.

## Installation

```bash
dotnet tool install -g dotnet10-hybrid-tool
```

## Usage

```bash
dotnet10-hybrid-tool
```

## Output

The tool displays:

- Runtime framework description
- Runtime identifier (RID)
- Compilation mode (Native AOT or CoreCLR)

## Packages

This tool is published as a hybrid package:

| Package | Description |
|---------|-------------|
| `dotnet10-hybrid-tool` | Pointer package (references RID-specific packages) |
| `dotnet10-hybrid-tool.any` | CoreCLR fallback for any platform |
| `dotnet10-hybrid-tool.osx-arm64` | Native AOT for macOS ARM64 |
| `dotnet10-hybrid-tool.linux-arm64` | Native AOT for Linux ARM64 |
| `dotnet10-hybrid-tool.linux-x64` | Native AOT for Linux x64 |

The .NET CLI automatically selects the appropriate package based on your platform.

## Hybrid Packaging Pattern

This project demonstrates a hybrid approach to RID-specific .NET tool packaging that combines Native AOT for select platforms with CoreCLR fallback for all others.

### The Pattern

1. **Use `ToolPackageRuntimeIdentifiers` with `PublishAot=true`**

   Setting `ToolPackageRuntimeIdentifiers` (rather than `RuntimeIdentifiers`) with `PublishAot=true` causes `dotnet pack` to generate only a pointer package with metadata. It does NOT generate RID-specific packages automatically because AOT compilation doesn't support cross-compilation across operating systems (only architectures).

2. **Generate Native AOT packages for desired RIDs**

   Run `dotnet pack -r <RID>` on each target platform to build Native AOT binaries.

   For example:

   ```bash
   dotnet pack -r osx-arm64      # on macOS
   dotnet pack -r linux-arm64    # on Linux ARM or in container
   dotnet pack -r linux-x64      # on Linux x64 or in container
   ```

3. **Generate CoreCLR fallback with `-r any`**

   Pack the `any` RID with `-p:PublishAot=false` to create a portable CoreCLR package:

   ```bash
   dotnet pack -r any -p:PublishAot=false
   ```

   Order of the steps doesn't matter.

### Why This Works

- **`PublishAot=true`** disables automatic RID-specific package generation during pack because AOT requires platform-specific builds
- **`ToolPackageRuntimeIdentifiers`** lists the RIDs you intend to support, creating the pointer package structure
- **Manual `-r <RID>` builds** produce AOT-compiled native binaries for each platform
- **`-r any -p:PublishAot=false`** generates a portable CoreCLR package as fallback for unlisted platforms

### Alternative: All-CoreCLR RID Packages

In contrast, if you use `RuntimeIdentifiers` (not `ToolPackageRuntimeIdentifiers`) and conditionalize `PublishAot` to a subset of RIDs, `dotnet pack` will generate RID-specific CoreCLR apps for all listed RIDs automatically. This works because CoreCLR supports cross-compilation, but you lose the AOT performance benefits or need to re-generate specific packages as NAOT, which is an odd approach.

### Benefits of This Hybrid Approach

- **Native AOT performance** on high-priority platforms (faster startup, smaller memory footprint)
- **Universal compatibility** via CoreCLR fallback for any platform
- **Explicit control** over which platforms get AOT vs. CoreCLR
- **Single installation command** for users - .NET CLI handles platform detection

## Build Environment

This demo was created on an Apple M4 machine, which influenced the platform choices:

- **macOS Arm64 (`osx-arm64`)**: Built natively on the M4 host, making it the natural first target
- **Linux Arm64 (`linux-arm64`)**: Built using the `mcr.microsoft.com/dotnet/sdk:10.0-noble-aot` Docker container, which runs natively on Apple Silicon
- **Linux x64 (`linux-x64`)**: Built using the same container with `--platform linux/amd64`, relying on Docker's emulation support (Rosetta 2) for cross-architecture builds

The complete build process is automated in [`build-packages.sh`](build-packages.sh), which demonstrates:

1. Creating the pointer package
2. Building Native AOT packages for each Linux RID using containers
3. Building the Native AOT package for macOS natively
4. Building the `any` CoreCLR fallback with `-p:PublishAot=false`

### Why No Windows AOT Build?

This demo doesn't include a Windows Native AOT build because:

1. Cross-compiling Windows binaries from macOS/Linux isn't supported by .NET AOT
2. Building Windows AOT requires running `dotnet pack -r win-x64` on an actual Windows machine
3. The `any` CoreCLR fallback package provides Windows support, just without AOT optimizations

**Tip for Windows users**: You can experience both variants on the same machine:

- Install the tool on Windows to use the CoreCLR fallback (`any` RID)
- Install the same tool in WSL to use the Native AOT Linux build (`linux-x64` or `linux-arm64`)
- Compare startup time and memory usage between the two!

For production tools that need Windows AOT support, you would need to either:

- Build on a Windows machine or Windows CI runner
- Use a multi-platform CI/CD pipeline (GitHub Actions, Azure Pipelines, etc.) that builds on Windows, Linux, and macOS

### References

- [Create RID-specific, self-contained, and AOT .NET tools](https://learn.microsoft.com/dotnet/core/tools/rid-specific-tools)
- [Native AOT deployment](https://learn.microsoft.com/dotnet/core/deploying/native-aot/)
