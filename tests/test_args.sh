#!/usr/bin/env bash
# tests/test_args.sh — build.sh argument parsing and validation
# Run: bash tests/test_args.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="${PROJECT_ROOT}/scripts/build.sh"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
cd "$TMPDIR"

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
assert_not_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if [[ "$haystack" != *"$needle"* ]]; then ok "$desc"
    else fail "$desc (needle='$needle' unexpectedly found)"; fi
}
assert_rc() {
    local desc="$1" expected="$2"; shift 2
    local rc=0; "$@" >/dev/null 2>&1 || rc=$?
    if [[ "$expected" == "$rc" ]]; then ok "$desc"
    else fail "$desc (expected rc=$expected, got rc=$rc)"; fi
}

# ── Help & version ───────────────────────────────────────────

section "Help & version"

run_cmd bash "$SCRIPT"
assert_eq "no args → exit 1" "1" "$_rc"
assert_contains "shows Usage" "Usage:" "$_out"

run_cmd bash "$SCRIPT" --help
assert_eq "--help → exit 0" "0" "$_rc"
assert_contains "help shows Usage" "Usage:" "$_out"
assert_contains "help shows clone" "clone" "$_out"
assert_contains "help shows build" "build" "$_out"
assert_contains "help shows --arch" "--arch" "$_out"

run_cmd bash "$SCRIPT" -h
assert_eq "-h → exit 0" "0" "$_rc"

# ── Unknown command ───────────────────────────────────────

section "Unknown command"

run_cmd bash "$SCRIPT" unknown
assert_eq "unknown command → exit 1" "1" "$_rc"
assert_contains "unknown error" "Unknown command" "$_out"

run_cmd bash "$SCRIPT" clone
assert_eq "missing clone target → exit 1" "1" "$_rc"
assert_contains "missing command" "Error: missing command" "$_out"

run_cmd bash "$SCRIPT" build
assert_eq "missing --arch → exit 1" "1" "$_rc"
assert_contains "--arch required" "--arch is required" "$_out"

# ── Invalid --arch ─────────────────────────────────────────

section "Invalid --arch"

run_cmd bash "$SCRIPT" build --arch arm
assert_eq "invalid arch (arm) → exit 1" "1" "$_rc"
assert_contains "arch must be arm64 or amd64" "arm64 or amd64" "$_out"

run_cmd bash "$SCRIPT" build --arch x86_64
assert_eq "invalid arch (x86_64) → exit 1" "1" "$_rc"

run_cmd bash "$SCRIPT" build --arch x64
assert_eq "invalid arch (x64) → exit 1" "1" "$_rc"

run_cmd bash "$SCRIPT" build --arch arm65
assert_eq "invalid arch (arm65) → exit 1" "1" "$_rc"

# ── Valid --arch ─────────────────────────────────────────

section "Valid --arch"

run_cmd bash "$SCRIPT" build --arch arm64
assert_eq "valid arch arm64 → exit 1 (no repo)" "1" "$_rc"
assert_contains "attempts to clone" "not found" "$_out"

run_cmd bash "$SCRIPT" build --arch amd64
assert_eq "valid arch amd64 → exit 1 (no repo)" "1" "$_rc"
assert_contains "attempts to clone" "not found" "$_out"

# ── Unknown clone target ───────────────────────────────────

section "Unknown clone target"

run_cmd bash "$SCRIPT" clone unknown
assert_eq "unknown clone target → exit 1" "1" "$_rc"
assert_contains "Unknown clone target" "Unknown clone target" "$_out"

run_cmd bash "$SCRIPT" clone sing-box --sing-box "${TMPDIR}/nonexistent/path"
assert_eq "nonexistent --sing-box → exit 0 (git fails but no -e)" "0" "$_rc"
assert_contains "VERSION file not found" "VERSION file not found" "$_out"

# ── Options passthrough ───────────────────────────────────

section "Options passthrough"

run_cmd bash "$SCRIPT" --sing-box
assert_eq "--sing-box as command → exit 1" "1" "$_rc"
assert_contains "Unknown command" "Unknown command" "$_out"

run_cmd bash "$SCRIPT" build --arch
assert_eq "--arch without arg → exit 1" "1" "$_rc"

run_cmd bash "$SCRIPT" build --sing-box
assert_eq "--sing-box without arg → exit 1" "1" "$_rc"

run_cmd bash "$SCRIPT" build --output
assert_eq "--output without arg → exit 1" "1" "$_rc"

# ── Summary ────────────────────────────────────────────

echo ""
echo "════════════════════════════════════"
echo " test_args.sh: ${PASS} passed, ${FAIL} failed (total: ${TESTS})"
echo "════════════════════════════════════"
[[ $FAIL -eq 0 ]]