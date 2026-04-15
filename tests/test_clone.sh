#!/usr/bin/env bash
# tests/test_clone.sh — build.sh clone behavior
# Run: bash tests/test_clone.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="${PROJECT_ROOT}/scripts/build.sh"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
mkdir -p "${TMPDIR}/.github"
mkdir -p "${TMPDIR}/src"
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
assert_file_exists() {
    local desc="$1" path="$2"
    if [[ -e "$path" ]]; then ok "$desc"
    else fail "$desc (missing: $path)"; fi
}
assert_file_not_exists() {
    local desc="$1" path="$2"
    if [[ ! -e "$path" ]]; then ok "$desc"
    else fail "$desc (unexpected: $path)"; fi
}

# Create VERSION files for testing
echo "v1.13.8" > "${TMPDIR}/VERSION"
echo "v1.13.8" > "${TMPDIR}/.github/CRONET_GO_VERSION"

# ── Clone skip if exists (git repo) ───────────────────────

section "Clone skip if exists (git repo)"

# Create existing sing-box git directory
SING_BOX_DIR="${TMPDIR}/src/sing-box"
mkdir -p "$SING_BOX_DIR"
touch "${SING_BOX_DIR}/.git"

run_cmd bash "$SCRIPT" clone sing-box --sing-box "$SING_BOX_DIR"
assert_eq "existing sing-box git → skip" "0" "$_rc"
assert_contains "already exists at" "already exists at" "$_out"

# ── Error if not git repo (cronet-go) ────────────────────

section "Error if not git repo"

# Create non-git directory
NOT_GIT_DIR="${TMPDIR}/src/not-git"
mkdir -p "$NOT_GIT_DIR"
touch "${NOT_GIT_DIR}/somefile"

run_cmd bash "$SCRIPT" clone cronet-go --cronet-go "$NOT_GIT_DIR"
assert_eq "non-git dir → error" "1" "$_rc"
assert_contains "not a git repository" "not a git repository" "$_out"

# ── Clone sing-box tries clone (may fail on network) ────────────────────

section "Clone sing-box tries clone"

run_cmd bash "$SCRIPT" clone sing-box --sing-box "${TMPDIR}/src/new-sing-box"
assert_eq "new sing-box → tries clone (network may fail)" "0" "$_rc"
assert_contains "Cloning into" "Cloning into" "$_out"

# ── Summary ────────────────────────────────────────────

echo ""
echo "════════════════════════════════════"
echo " test_clone.sh: ${PASS} passed, ${FAIL} failed (total: ${TESTS})"
echo "════════════════════════════════════"
[[ $FAIL -eq 0 ]]