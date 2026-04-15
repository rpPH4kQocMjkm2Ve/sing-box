#!/usr/bin/env bash
# tests/test_harness.sh
#
# Shared test harness for build.sh unit tests.
# Sourced by individual test files — NOT run directly.
#
# Provides:
#   - Assertion functions (ok, fail, assert_eq, assert_match, assert_contains, etc.)
#   - run_cmd / assert_rc helpers
#   - Temporary TESTDIR with EXIT cleanup
#   - MOCK_BIN on PATH with default mocks
#   - make_mock utility
#   - Mock call tracking (mock_call_count, mock_last_args)
#   - PROJECT_ROOT variable

set -uo pipefail

PASS=0
FAIL=0
TESTS=0

# ── Test helpers ─────────────────────────────────────────────

ok() {
    PASS=$((PASS + 1))
    TESTS=$((TESTS + 1))
    echo "  ✓ $1"
}

fail() {
    FAIL=$((FAIL + 1))
    TESTS=$((TESTS + 1))
    echo "  ✗ $1"
}

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        ok "$desc"
    else
        fail "$desc (expected='$expected', got='$actual')"
    fi
}

assert_match() {
    local desc="$1" pattern="$2" actual="$3"
    if [[ "$actual" =~ $pattern ]]; then
        ok "$desc"
    else
        fail "$desc (pattern='$pattern' not found in '$actual')"
    fi
}

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        ok "$desc"
    else
        fail "$desc (needle='$needle' not in output)"
    fi
}

assert_not_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        ok "$desc"
    else
        fail "$desc (needle='$needle' unexpectedly found)"
    fi
}

assert_file_exists() {
    local desc="$1" path="$2"
    if [[ -e "$path" ]]; then
        ok "$desc"
    else
        fail "$desc (missing: $path)"
    fi
}

assert_file_not_exists() {
    local desc="$1" path="$2"
    if [[ ! -e "$path" ]]; then
        ok "$desc"
    else
        fail "$desc (unexpected: $path)"
    fi
}

# Run command in subshell, capture rc + combined stdout/stderr.
# Sets globals: _rc, _out
run_cmd() {
    _rc=0
    _out=$("$@" 2>&1) || _rc=$?
}

# Check only the return code (suppress output).
assert_rc() {
    local desc="$1" expected="$2"
    shift 2
    local rc=0
    "$@" >/dev/null 2>&1 || rc=$?
    assert_eq "$desc" "$expected" "$rc"
}

section() {
    echo ""
    echo "── $1 ──"
}

# ── Mock call tracking ──────────────────────────────────────

mock_call_count() {
    local name="$1"
    local log="${TESTDIR}/mock_calls_${name}.log"
    if [[ -f "$log" ]]; then
        wc -l < "$log" | tr -d ' '
    else
        echo "0"
    fi
}

mock_last_args() {
    local name="$1"
    local log="${TESTDIR}/mock_calls_${name}.log"
    if [[ -f "$log" ]]; then
        tail -1 "$log"
    else
        echo ""
    fi
}

# ── Setup test environment ───────────────────────────────────

TESTDIR=$(mktemp -d)
trap 'rm -rf "$TESTDIR"' EXIT

MOCK_BIN="${TESTDIR}/mock_bin"
mkdir -p "$MOCK_BIN"

ORIG_PATH="$PATH"
export PATH="${MOCK_BIN}:${PATH}"

# Write a mock script into MOCK_BIN.
# Args: name [body]
make_mock() {
    local name="$1"; shift
    local body="${*:-exit 0}"
    local log_file="${TESTDIR}/mock_calls_${name}.log"
    : > "$log_file"
    cat > "${MOCK_BIN}/${name}" <<ENDSCRIPT
#!/bin/bash
printf '%s\n' "\$*" >> "${log_file}"
${body}
ENDSCRIPT
    chmod +x "${MOCK_BIN}/${name}"
}

# ── Resolve project root ───────────────────────────────────────

_HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$_HARNESS_DIR/.." && pwd)"
SCRIPT="${PROJECT_ROOT}/scripts/build.sh"

# ── Summary function ─────────────────────────────────────────

summary() {
    local name="${0##*/}"
    echo ""
    echo "════════════════════════════════════"
    echo " ${name}: ${PASS} passed, ${FAIL} failed (total: ${TESTS})"
    echo "════════════════════════════════════"

    if [[ $FAIL -ne 0 ]]; then
        exit 1
    fi
    exit 0
}