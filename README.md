# sing-box container image

[![Build](https://github.com/fkzys/sing-box/actions/workflows/build.yml/badge.svg)](https://github.com/fkzys/sing-box/actions/workflows/build.yml)
![Version](https://img.shields.io/badge/version-1.13.9-blue)
![Platform](https://img.shields.io/badge/platform-linux%2Famd64%2Clinux%2Farm64-lightgrey)
![License](https://img.shields.io/github/license/fkzys/sing-box)

OCI image build of [sing-box](https://github.com/SagerNet/sing-box) with a curated set of build tags, published to GitHub Container Registry.

The resulting image is consumed by the infrastructure repository [fkzys/infra](https://github.com/fkzys/infra).

## Image

```
ghcr.io/<owner>/<OBFS_NAME>:<version>
ghcr.io/<owner>/<OBFS_NAME>:latest
```

Where `OBFS_NAME` is stored in `OBFS_NAME` file (generated once). The binary inside the container is symlinked from `bin` to `<OBFS_NAME>`.

### Build tags

The following build tags are enabled in this image:

| Tag | Description |
|-----|-------------|
| `with_gvisor` | gVisor userspace network stack (Tun inbound, WireGuard outbound) |
| `with_wireguard` | WireGuard outbound support |
| `with_naive_outbound` | NaiveProxy outbound support |
| `with_musl` | (arm64) Static musl build for alpine compatibility |
| `with_quic` | QUIC support (QUIC/HTTP3 DNS, Naive inbound, Hysteria) |
| `badlinkname` | Enable `go:linkname` access to internal stdlib functions (required for kTLS and raw TLS record manipulation) |
| `tfogo_checklinkname0` | Companion to `badlinkname`; signals the build uses `-checklinkname=0` to bypass Go 1.23+ linker restrictions |

### Linker flags

| Flag | Description |
|------|-------------|
| `-X 'internal/godebug.defaultGODEBUG=multipathtcp=0'` | Go 1.24 enabled MPTCP for listeners by default; this disables it because sing-box has its own MPTCP control (`tcp_multi_path` option) |
| `-checklinkname=0` | Disables Go 1.23+ linker check on `go:linkname` usage (required together with the `badlinkname` build tag) |
| `-s -w` | Strip debug symbols |

> **Note:** This build does **not** include every default upstream tag. Tags like `with_dhcp`, `with_utls`, `with_clash_api`, `with_acme`, `with_tailscale`, `with_ccm`, and `with_ocm` are omitted to keep the image minimal. See the [upstream documentation](https://sing-box.sagernet.org/installation/build-from-source/) for the full list.

### Base image

`alpine` with `bash`, `tzdata`, `ca-certificates`, and `nftables`.

## CI

The GitHub Actions workflow (`.github/workflows/build.yml`) triggers on:

- push to `main`
- manual `workflow_dispatch`

It reads the target version from the `VERSION` file, clones the corresponding upstream tag, builds the image with `podman build`, and pushes it to GHCR.

## Updating the version

1. Check the latest upstream tags:

```bash
make check-upstream
```

2. Update the `VERSION` file:

```bash
echo 'v1.13.2' > VERSION
```

3. Commit and push to `main` — CI will build and publish the image automatically.

## Local build

Two options:

### Container (OCI image)

Requires `podman` (or a compatible runtime) and `make`.

```bash
# Build the image
make build VERSION=v1.13.2

# Push to registry (requires podman login)
make push VERSION=v1.13.2

# Clean the build directory
make clean

# List latest upstream tags
make check-upstream
```

Override the target platform:

```bash
make build VERSION=v1.13.2 PLATFORM=linux/arm64
```

### Binaries (host system)

Requires `go`, `git`, `dpkg`, `dpkg-deb` (for arm64).

```bash
# Clone repositories
./scripts/build.sh clone sing-box
./scripts/build.sh clone cronet-go
./scripts/build.sh clone toolchain

# Build
./scripts/build.sh build --arch amd64
./scripts/build.sh build --arch arm64
```

Output: `output/sing-box_{amd64,arm64}`.

## Repository structure

```
.
├── .github/workflows/build.yml   # CI pipeline
├── Dockerfile                    # Multi-stage build
├── Makefile                      # Local build helpers (container)
├── scripts/build.sh              # Build binaries for host system
├── VERSION                       # Current target upstream version
└── README.md
```
