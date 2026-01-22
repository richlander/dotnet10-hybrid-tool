# HelloRid

A demo .NET tool showing RID-specific packaging with Native AOT.

## Installation

```bash
dotnet tool install -g HelloRid
```

## Usage

```bash
hellorid
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
| `HelloRid` | Pointer package (references RID-specific packages) |
| `HelloRid.any` | CoreCLR fallback for any platform |
| `HelloRid.osx-arm64` | Native AOT for macOS ARM64 |
| `HelloRid.linux-arm64` | Native AOT for Linux ARM64 |
| `HelloRid.linux-x64` | Native AOT for Linux x64 |

The .NET CLI automatically selects the appropriate package based on your platform.
