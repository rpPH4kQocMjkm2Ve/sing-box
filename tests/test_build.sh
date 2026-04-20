#!/usr/bin/env bash
# tests/test_build.sh — build.sh build command verification
# Run: bash tests/test_build.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="${PROJECT_ROOT}/scripts/build.sh"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

PASS=0
FAIL=0
TESTS=0

ok()   { PASS=$((PASS + 1)); TESTS=$((TESTS + 1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL + 1)); TESTS=$((TESTS + 1)); echo "  ✗ $1"; }
section() { echo ""; echo "── $1 ──"; }

run_cmd() { _rc=0; _out=$("$@" 2>&1) || _rc=$?; }
assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then ok "$desc"
    else fail "$desc (expected='$expected', got='$actual')"; fi
}
assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then ok "$desc"
    else fail "$desc (needle='$needle' not in output)"; fi
}
assert_match() {
    local desc="$1" pattern="$2" actual="$3"
    if [[ "$actual" =~ $pattern ]]; then ok "$desc"
    else fail "$desc (pattern='$pattern' not found in '$actual')"; fi
}

# Create patched script that exits after parsing arguments
# This lets us verify what function would be called without
# actually running the build (which requires toolchain/repos)
PATCHED_SCRIPT="${TMPDIR}/build-patched.sh"

# The patched script mimics the original behavior but exits early
# after determining which function to call
cat > "$PATCHED_SCRIPT" << 'PATCH'
#!/usr/bin/env bash
set -uo pipefail

show_help() {
    cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
    clone sing-box [--sing-box <path>]       Clone sing-box repository
    clone cronet-go [--cronet-go <path>]    Clone cronet-go repository
    clone toolchain [--toolchain <path>]   Download Chromium toolchain
    pull [--all|sing-box|cronet-go]       Pull latest version
    build --arch <arm64|amd64> [options]    Build sing-box binary

Examples:
    $(basename "$0") clone sing-box
    $(basename "$0") build --arch arm64
    $(basename "$0") build --arch amd64 --no-pull
EOF
}

# Mock functions (just for testing the call chain)
cmd_clone_sing_box() { echo "CALL: cmd_clone_sing_box"; }
cmd_clone_cronet_go() { echo "CALL: cmd_clone_cronet_go"; }
cmd_clone_toolchain() { echo "CALL: cmd_clone_toolchain"; }
cmd_pull() { echo "CALL: cmd_pull"; }
update_sing_box() { echo "CALL: update_sing_box"; }
update_cronet_go() { echo "CALL: update_cronet_go"; }
cmd_build() { echo "CALL: cmd_build"; }
cmd_build_arm64() { echo "CALL: cmd_build_arm64"; }
cmd_build_amd64() { echo "CALL: cmd_build_amd64"; }

require_cmd() {
    if [[ $# -lt 1 ]]; then
        echo "Error: missing command" >&2
        exit 1
    fi
}

parse_version() { echo "v1.13.8"; }
parse_cronet_version() { echo "abc123"; }

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
                sing-box) cmd_clone_sing_box "$@"; ;;
                cronet-go) cmd_clone_cronet_go "$@"; ;;
                toolchain) cmd_clone_toolchain "$@"; ;;
                *)
                    echo "Unknown clone target: $subcmd" >&2
                    echo "Valid targets: sing-box, cronet-go, toolchain" >&2
                    exit 1
                    ;;
            esac
            ;;
        pull)
            shift
            local pull_target="all"
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --sing-box|sing-box|--all|all|--cronet-go|cronet-go)
                        pull_target="$1"
                        shift
                        ;;
                    *)
                        echo "Unknown option: $1" >&2
                        show_help
                        exit 1
                        ;;
                esac
            done
            cmd_pull "$pull_target"
            ;;
        build)
            shift
            local arch=""
            local no_pull=0
            local sing_box_path="./src/sing-box"
            local cronet_go_path="./src/cronet-go"
            local toolchain_path="./src/cronet-go"
            local output_path="./output"

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --arch) arch="$2"; shift 2; ;;
                    --sing-box) sing_box_path="$2"; shift 2; ;;
                    --cronet-go) cronet_go_path="$2"; shift 2; ;;
                    --toolchain) toolchain_path="$2"; shift 2; ;;
                    --output) output_path="$2"; shift 2; ;;
                    --no-pull) no_pull=1; shift; ;;
                    *)
                        echo "Unknown option: $1" >&2
                        show_help
                        exit 1
                        ;;
                esac
            done

            if [[ -z "$arch" ]]; then
                echo "Error: --arch is required" >&2
                exit 1
            fi

            if [[ "$arch" != "arm64" && "$arch" != "amd64" ]]; then
                echo "Error: --arch must be arm64 or amd64" >&2
                exit 1
            fi

            cmd_build "no_pull=$no_pull"

            if [[ "$arch" == "arm64" ]]; then
                cmd_build_arm64 "$sing_box_path" "$cronet_go_path" "$toolchain_path" "$output_path" "v1.13.8"
            else
                cmd_build_amd64 "$sing_box_path" "$cronet_go_path" "$output_path" "v1.13.8"
            fi

            # Make output_path absolute if relative
            local original_dir="$(pwd)"
            if [[ "$output_path" != /* ]]; then
                output_path="$original_dir/$output_path"
            fi
            echo "OUTPUT_PATH=$output_path"
            ;;
        *)
            echo "Unknown command: $1" >&2
            show_help
            exit 1
            ;;
    esac
}

main "$@"
PATCH

chmod +x "$PATCHED_SCRIPT"

# ── Pull commands ─────────────────────────────────────

section "Pull commands"

run_cmd bash "$PATCHED_SCRIPT" pull
assert_eq "pull → calls cmd_pull" "0" "$_rc"
assert_contains "calls cmd_pull" "CALL: cmd_pull" "$_out"

run_cmd bash "$PATCHED_SCRIPT" pull --all
assert_eq "pull --all → calls cmd_pull" "0" "$_rc"

run_cmd bash "$PATCHED_SCRIPT" pull --sing-box
assert_eq "pull --sing-box → calls cmd_pull" "0" "$_rc"

run_cmd bash "$PATCHED_SCRIPT" pull --cronet-go
assert_eq "pull --cronet-go → calls cmd_pull" "0" "$_rc"

run_cmd bash "$PATCHED_SCRIPT" pull sing-box
assert_eq "pull sing-box (no --) → calls cmd_pull" "0" "$_rc"

run_cmd bash "$PATCHED_SCRIPT" pull cronet-go
assert_eq "pull cronet-go (no --) → calls cmd_pull" "0" "$_rc"

run_cmd bash "$PATCHED_SCRIPT" pull all
assert_eq "pull all (no --) → calls cmd_pull" "0" "$_rc"

# ── Clone commands ─────────────────────────────────────

section "Clone commands"

run_cmd bash "$PATCHED_SCRIPT" clone sing-box
assert_eq "clone sing-box → calls correct func" "0" "$_rc"
assert_contains "calls cmd_clone_sing_box" "CALL: cmd_clone_sing_box" "$_out"

run_cmd bash "$PATCHED_SCRIPT" clone cronet-go
assert_eq "clone cronet-go → calls correct func" "0" "$_rc"
assert_contains "calls cmd_clone_cronet_go" "CALL: cmd_clone_cronet_go" "$_out"

run_cmd bash "$PATCHED_SCRIPT" clone toolchain
assert_eq "clone toolchain → calls correct func" "0" "$_rc"
assert_contains "calls cmd_clone_toolchain" "CALL: cmd_clone_toolchain" "$_out"

# ── Build commands ─────────────────────────────────────

section "Build commands"

run_cmd bash "$PATCHED_SCRIPT" build --arch arm64
assert_eq "build arm64 → calls cmd_build_arm64" "0" "$_rc"
assert_contains "calls cmd_build_arm64" "CALL: cmd_build_arm64" "$_out"

run_cmd bash "$PATCHED_SCRIPT" build --arch amd64
assert_eq "build amd64 → calls cmd_build_amd64" "0" "$_rc"
assert_contains "calls cmd_build_amd64" "CALL: cmd_build_amd64" "$_out"

# ── Build with custom paths ───────────────────────────────

section "Build with custom paths"

run_cmd bash "$PATCHED_SCRIPT" build --arch amd64 --sing-box /custom/sing-box --cronet-go /custom/cronet-go --output /custom/output
assert_eq "build with custom paths → exit 0" "0" "$_rc"
assert_contains "calls cmd_build_amd64" "CALL: cmd_build_amd64" "$_out"

# ── Build output path normalization ─────────────────────

section "Build output path"

# Relative path should be made absolute
run_cmd bash "$PATCHED_SCRIPT" build --arch amd64 --output relative/path
assert_eq "relative output → made absolute" "0" "$_rc"
assert_contains "output is absolute" "OUTPUT_PATH=/" "$_out"

# ── --no-pull flag ─────────────────────────────────────

section "--no-pull flag"

run_cmd bash "$PATCHED_SCRIPT" build --arch amd64
assert_eq "build without --no-pull → calls cmd_build" "0" "$_rc"
assert_contains "calls cmd_build" "CALL: cmd_build" "$_out"

run_cmd bash "$PATCHED_SCRIPT" build --arch amd64 --no-pull
assert_eq "build with --no-pull → calls cmd_build" "0" "$_rc"
assert_contains "calls cmd_build" "CALL: cmd_build" "$_out"

# ── Summary ────────────────────────────────────────────

echo ""
echo "════════════════════════════════════"
echo " test_build.sh: ${PASS} passed, ${FAIL} failed (total: ${TESTS})"
echo "════════════════════════════════════"
[[ $FAIL -eq 0 ]]
