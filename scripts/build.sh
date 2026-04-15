#!/usr/bin/env bash
set -uo pipefail

SING_BOX_DEFAULT="./src/sing-box"
CRONET_GO_DEFAULT="./src/cronet-go"
TOOLCHAIN_DEFAULT="./src/cronet-go"
OUTPUT_DEFAULT="./output"

UPSTREAM_SING_BOX="https://github.com/SagerNet/sing-box.git"
UPSTREAM_CRONET_GO="https://github.com/sagernet/cronet-go.git"

ARM64_TAGS="with_gvisor,with_utls,with_naive_outbound,with_quic,with_grpc,with_musl,badlinkname,tfogo_checklinkname0"
AMD64_TAGS="with_gvisor,with_utls,with_naive_outbound,with_quic,with_grpc,with_purego,badlinkname,tfogo_checklinkname0"
LDFLAGS="-s -w -checklinkname=0"

show_help() {
    cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
    clone sing-box [--sing-box <path>]       Clone sing-box repository
    clone cronet-go [--cronet-go <path>]    Clone cronet-go repository
    clone toolchain [--toolchain <path>]    Download Chromium toolchain
    build --arch <arm64|amd64> [options]    Build sing-box binary

Clone options:
    --sing-box <path>    Path for sing-box (default: $SING_BOX_DEFAULT)
    --cronet-go <path>   Path for cronet-go (default: $CRONET_GO_DEFAULT)
    --toolchain <path>   Path for toolchain (default: $TOOLCHAIN_DEFAULT)

Build options:
    --sing-box <path>    Path to sing-box (default: $SING_BOX_DEFAULT)
    --cronet-go <path>   Path to cronet-go (default: $CRONET_GO_DEFAULT)
    --toolchain <path>  Path to toolchain (default: $TOOLCHAIN_DEFAULT)
    --output <path>     Output directory (default: $OUTPUT_DEFAULT)

Examples:
    $(basename "$0") clone sing-box
    $(basename "$0") clone cronet-go
    $(basename "$0") clone toolchain
    $(basename "$0") build --arch arm64
    $(basename "$0") build --arch amd64
EOF
}

require_cmd() {
    if [[ $# -lt 1 ]]; then
        echo "Error: missing command"
        show_help
        exit 1
    fi
}

parse_version() {
    local path="$1"
    if [[ ! -f "$path/VERSION" ]]; then
        echo "Error: VERSION file not found in $path"
        exit 1
    fi
    cat "$path/VERSION"
}

parse_cronet_version() {
    local sing_box_path="$1"
    local cronet_version_file="$sing_box_path/.github/CRONET_GO_VERSION"
    if [[ ! -f "$cronet_version_file" ]]; then
        echo "Error: CRONET_GO_VERSION not found in $sing_box_path"
        exit 1
    fi
    cat "$cronet_version_file"
}

cmd_clone_sing_box() {
    local path="$SING_BOX_DEFAULT"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --sing-box)
                path="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    if [[ -d "$path" ]]; then
        echo "sing-box already exists at $path, skipping."
        return 0
    fi

    local version
    version=$(parse_version "$(pwd)")

    echo "Cloning sing-box $version into $path..."
    mkdir -p "$(dirname "$path")"
    git clone --branch "$version" --depth 1 "$UPSTREAM_SING_BOX" "$path"
    echo "Done."
}

cmd_clone_cronet_go() {
    local path="$CRONET_GO_DEFAULT"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --cronet-go)
                path="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    if [[ -d "$path" ]]; then
        if [[ -d "$path/.git" ]]; then
            echo "cronet-go already exists at $path, skipping."
            return 0
        else
            echo "Error: $path exists but is not a git repository" >&2
            return 1
        fi
    fi

    local version
    if [[ -f ".github/CRONET_GO_VERSION" ]]; then
        version=$(cat ".github/CRONET_GO_VERSION")
    else
        local cronet_parent="$(dirname "$path")"
        local sing_box_path="${cronet_parent}/sing-box"
        version=$(parse_cronet_version "$sing_box_path" 2>/dev/null) || {
            echo "Error: CRONET_GO_VERSION not found. Run: $(basename "$0") clone sing-box first"
            exit 1
        }
    fi

    echo "Cloning cronet-go $version into $path..."
    mkdir -p "$(dirname "$path")"
    git init "$path"
    git -C "$path" remote add origin "$UPSTREAM_CRONET_GO"
    git -C "$path" fetch --depth=1 origin "$version"
    git -C "$path" checkout FETCH_HEAD
    git -C "$path" submodule update --init --recursive --depth=1
    echo "Done."
}

cmd_clone_toolchain() {
    local path="$TOOLCHAIN_DEFAULT"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --toolchain)
                path="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    local version
    version=$(parse_cronet_version "$path/../sing-box")

    echo "Downloading Chromium toolchain for cronet-go $version..."
    cd "$path"
    go run ./cmd/build-naive --target=linux/arm64 --libc=musl download-toolchain
    echo "Done."
}

cmd_build() {
    local arch=""
    local sing_box_path="$SING_BOX_DEFAULT"
    local cronet_go_path="$CRONET_GO_DEFAULT"
    local toolchain_path="$TOOLCHAIN_DEFAULT"
    local output_path="$OUTPUT_DEFAULT"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --arch)
                arch="$2"
                shift 2
                ;;
            --sing-box)
                sing_box_path="$2"
                shift 2
                ;;
            --cronet-go)
                cronet_go_path="$2"
                shift 2
                ;;
            --toolchain)
                toolchain_path="$2"
                shift 2
                ;;
            --output)
                output_path="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    local original_dir="$(pwd)"
    if [[ "$output_path" != /* ]]; then
        output_path="$original_dir/$output_path"
    fi

    if [[ -z "$arch" ]]; then
        echo "Error: --arch is required"
        show_help
        exit 1
    fi

    if [[ "$arch" != "arm64" && "$arch" != "amd64" ]]; then
        echo "Error: --arch must be arm64 or amd64"
        exit 1
    fi

    local version
    if [[ -f "VERSION" ]]; then
        version=$(cat VERSION)
    else
        version=$(parse_version "$sing_box_path")
    fi
    version="${version#v}"

    if [[ ! -d "$sing_box_path" ]]; then
        echo "sing-box not found at $sing_box_path, cloning..."
        cmd_clone_sing_box
    fi

    if [[ ! -d "$cronet_go_path" ]]; then
        echo "cronet-go not found at $cronet_go_path, cloning..."
        cmd_clone_cronet_go
    fi

    echo "Building sing-box $version for $arch..."

    mkdir -p "$output_path"

    if [[ "$arch" == "arm64" ]]; then
        cmd_build_arm64 "$sing_box_path" "$cronet_go_path" "$toolchain_path" "$output_path" "$version"
    else
        cmd_build_amd64 "$sing_box_path" "$cronet_go_path" "$output_path" "$version"
    fi

    echo "Done: $output_path/sing-box_$arch"
}

check_arm64_deps() {
    local missing=()
    for cmd in dpkg-deb dpkg; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Error: Missing required tools: ${missing[*]}"
        echo "Install with: sudo apt-get install ${missing[*]}"
        return 1
    fi
}

cmd_build_arm64() {
    local sing_box_path="$1"
    local cronet_go_path="$2"
    local toolchain_path="$3"
    local output_path="$4"
    local version="$5"

    echo "Building arm64 with CGO (requires libcronet.so)..."

    check_arm64_deps || exit 1

    local original_dir="$(pwd)"
    cronet_go_path="$(cd "$(dirname "$cronet_go_path")" && pwd)/$(basename "$cronet_go_path")"
    sing_box_path="$(cd "$(dirname "$sing_box_path")" && pwd)/$(basename "$sing_box_path")"

    cd "$cronet_go_path"

    if [[ -d "naiveproxy/src/third_party/llvm-build/Release+Asserts/bin/clang" ]]; then
        echo "Toolchain already present."
    else
        echo "Downloading Chromium toolchain..."
        go run ./cmd/build-naive --target=linux/arm64 --libc=musl download-toolchain
    fi

    echo "Setting Chromium toolchain environment..."
    while IFS='=' read -r key value; do
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        export "$key=$value"
    done < <(go run ./cmd/build-naive --target=linux/arm64 --libc=musl env)

    cd "$sing_box_path"
    mkdir -p dist

    CGO_ENABLED=1 GOOS=linux GOARCH=arm64 \
        go build -v -trimpath -buildvcs=false -o dist/sing-box -tags "$ARM64_TAGS" \
        -ldflags "-s -w -checklinkname=0 -X 'github.com/sagernet/sing-box/constant.Version=v$version'" \
        ./cmd/sing-box

    echo "Extracting libcronet.so..."
    cd "$cronet_go_path"
    CGO_ENABLED=0 go run ./cmd/build-naive extract-lib --target linux/arm64 -n libcronet.so -o dist

    cp "$sing_box_path/dist/sing-box" "$output_path/sing-box_arm64"
    cp "$cronet_go_path/dist/libcronet.so" "$output_path/libcronet_arm64.so"
}

cmd_build_amd64() {
    local sing_box_path="$1"
    local cronet_go_path="$2"
    local output_path="$3"
    local version="$4"

    local original_dir="$(pwd)"
    cronet_go_path="$(cd "$(dirname "$cronet_go_path")" && pwd)/$(basename "$cronet_go_path")"
    sing_box_path="$(cd "$(dirname "$sing_box_path")" && pwd)/$(basename "$sing_box_path")"

    echo "Building amd64 with purego..."

    cd "$sing_box_path"

    go build -tags "$AMD64_TAGS" -v -trimpath \
        -ldflags "$LDFLAGS -X 'github.com/sagernet/sing-box/constant.Version=v$version'" \
        -o "$output_path/sing-box_amd64" ./cmd/sing-box

    echo "Extracting libcronet.so..."
    cd "$cronet_go_path"
    mkdir -p dist
    CGO_ENABLED=0 go run ./cmd/build-naive extract-lib --target linux/amd64 -n libcronet.so -o dist
    cp "$cronet_go_path/dist/libcronet.so" "$output_path/libcronet_amd64.so"
}

main() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 1
    fi

    case "$1" in
        --help|-h)
            show_help
            exit 0
            ;;
        clone)
            shift
            require_cmd "$@"
            local subcmd="$1"
            shift
            case "$subcmd" in
                sing-box)
                    cmd_clone_sing_box "$@"
                    ;;
                cronet-go)
                    cmd_clone_cronet_go "$@"
                    ;;
                toolchain)
                    cmd_clone_toolchain "$@"
                    ;;
                *)
                    echo "Unknown clone target: $subcmd"
                    echo "Valid targets: sing-box, cronet-go, toolchain"
                    exit 1
                    ;;
            esac
            ;;
        build)
            shift
            cmd_build "$@"
            ;;
        *)
            echo "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
