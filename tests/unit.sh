#!/usr/bin/env bash
# Unit tests for the pure shell helpers used by retro.
set -uo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

# shellcheck source=/dev/null
source "$REPO_ROOT/retrolib/helpers.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/retrolib/qemu.sh"

tests_run=0
tests_failed=0

# Asserts that two strings are equal.
assert_eq() {
    local label=$1 expected=$2 actual=$3
    tests_run=$((tests_run + 1))
    if [ "$expected" != "$actual" ]; then
        tests_failed=$((tests_failed + 1))
        printf 'FAIL %s\n  expected: [%s]\n  actual:   [%s]\n' "$label" "$expected" "$actual"
    fi
}

# Asserts that a command succeeds.
assert_ok() {
    local label=$1
    shift
    tests_run=$((tests_run + 1))
    if ! "$@"; then
        tests_failed=$((tests_failed + 1))
        printf 'FAIL %s (expected success)\n' "$label"
    fi
}

# Asserts that a command fails.
assert_fail() {
    local label=$1
    shift
    tests_run=$((tests_run + 1))
    if "$@"; then
        tests_failed=$((tests_failed + 1))
        printf 'FAIL %s (expected failure)\n' "$label"
    fi
}

# --- shell_quote_word -------------------------------------------------------
assert_eq "quote/plain" "plain" "$(shell_quote_word plain)"
assert_eq "quote/comma-eq" "if=ide,index=0" "$(shell_quote_word 'if=ide,index=0')"
assert_eq "quote/space" "'a b'" "$(shell_quote_word 'a b')"
assert_eq "quote/empty" "''" "$(shell_quote_word '')"
assert_eq "quote/single-quote" "'a'\\''b'" "$(shell_quote_word "a'b")"
assert_eq "quote/amp" "'a&b'" "$(shell_quote_word 'a&b')"

# --- path_is_safe_relative --------------------------------------------------
assert_ok   "safe/sub"        path_is_safe_relative "a/b.tgz"
assert_ok   "safe/single"     path_is_safe_relative "file.iso"
assert_fail "safe/abs"        path_is_safe_relative "/etc/passwd"
assert_fail "safe/dotdot"     path_is_safe_relative "../x"
assert_fail "safe/mid-dotdot" path_is_safe_relative "a/../b"
assert_fail "safe/empty"      path_is_safe_relative ""
assert_fail "safe/bare-dotdot" path_is_safe_relative ".."

# --- url_path_depth ---------------------------------------------------------
assert_eq "depth/one"   "1" "$(url_path_depth 'http://example.com/a')"
assert_eq "depth/three" "3" "$(url_path_depth 'http://example.com/a/b/c')"
assert_eq "depth/trailing" "2" "$(url_path_depth 'http://example.com/a/b/')"
assert_eq "depth/mirror" "2" "$(url_path_depth 'http://mirrors.slackware.com/slackware/slackware-3.6/')"

# --- retro_config_file ------------------------------------------------------
tmp=$(mktemp -d)
mkdir -p "$tmp/parent/child"
: >"$tmp/parent/shared.txt"
: >"$tmp/parent/child/local.txt"
assert_eq "config/local"  "$tmp/parent/child/local.txt"  "$(retro_config_file "$tmp/parent/child" local.txt)"
assert_eq "config/parent" "$tmp/parent/shared.txt"        "$(retro_config_file "$tmp/parent/child" shared.txt)"
assert_fail "config/missing" retro_config_file "$tmp/parent/child" missing.txt
rm -rf "$tmp"

# --- qemu_render_command_sh / _cmd ------------------------------------------
# shellcheck disable=SC2034  # Read by the render functions via the global.
QEMU_ARGS=(qemu-system-i386 -drive "if=ide,index=0,format=qcow2,file=hda.img" "weird arg" "amp&x" "pct%v" "par(s)")
assert_eq "render/sh" \
    "qemu-system-i386 -drive if=ide,index=0,format=qcow2,file=hda.img 'weird arg' 'amp&x' pct%v 'par(s)'" \
    "$(qemu_render_command_sh)"
assert_eq "render/cmd" \
    'qemu-system-i386 -drive if=ide,index=0,format=qcow2,file=hda.img "weird arg" "amp&x" pct%%v "par(s)"' \
    "$(qemu_render_command_cmd)"

# --- summary ----------------------------------------------------------------
echo
if [ "$tests_failed" -eq 0 ]; then
    echo "OK: $tests_run assertions passed."
    exit 0
fi
echo "FAILED: $tests_failed of $tests_run assertions failed."
exit 1
