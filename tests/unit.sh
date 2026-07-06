#!/usr/bin/env bash
# Unit tests for the pure shell helpers used by retro.
set -uo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

# shellcheck source=/dev/null
source "$REPO_ROOT/retrolib/helpers.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/retrolib/logging.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/retrolib/qemu.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/retrolib/script.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/retrolib/slackware.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/retrolib/extract.sh"

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

# --- script_import ----------------------------------------------------------
imp_tmp=$(mktemp -d)
mkdir -p "$imp_tmp/distro/1.0"
printf 'imported_ok() { echo yes; }\n' >"$imp_tmp/distro/helper.sh"
printf 'broken() {\n}\n' >"$imp_tmp/distro/broken.sh"

# A good helper is sourced relative to the install script's directory.
assert_eq "import/good-helper" "yes" "$(
    QEMU_INSTALL_SCRIPT="$imp_tmp/distro/1.0/script.sh"
    script_import ../helper.sh
    imported_ok
)"

# A syntax error aborts the install subshell before any later commands run.
assert_eq "import/broken-aborts" "" "$(
    QEMU_INSTALL_SCRIPT="$imp_tmp/distro/1.0/script.sh"
    script_import ../broken.sh 2>/dev/null
    echo "not reached"
)"

# Runs script_import for a broken helper in a subshell to observe its status.
# shellcheck disable=SC2329 # Invoked indirectly by assert_fail.
import_broken_status() {
    (
        # shellcheck disable=SC2030,SC2034 # Read by script_import.
        QEMU_INSTALL_SCRIPT="$imp_tmp/distro/1.0/script.sh"
        script_import ../broken.sh 2>/dev/null
    )
}
assert_fail "import/broken-status" import_broken_status

# Runs script_import for a missing helper in a subshell to observe its status.
# shellcheck disable=SC2329 # Invoked indirectly by assert_fail.
import_missing_status() {
    (
        # shellcheck disable=SC2030,SC2034 # Read by script_import.
        QEMU_INSTALL_SCRIPT="$imp_tmp/distro/1.0/script.sh"
        script_import ../missing.sh 2>/dev/null
    )
}
assert_fail "import/missing-status" import_missing_status
rm -rf "$imp_tmp"

# --- qemu_render_command_sh / _cmd ------------------------------------------
# shellcheck disable=SC2034  # Read by the render functions via the global.
QEMU_ARGS=(qemu-system-i386 -drive "if=ide,index=0,format=qcow2,file=hda.img" "weird arg" "amp&x" "pct%v" "par(s)")
assert_eq "render/sh" \
    "qemu-system-i386 -drive if=ide,index=0,format=qcow2,file=hda.img 'weird arg' 'amp&x' pct%v 'par(s)'" \
    "$(qemu_render_command_sh)"
assert_eq "render/cmd" \
    'qemu-system-i386 -drive if=ide,index=0,format=qcow2,file=hda.img "weird arg" "amp&x" pct%%v "par(s)"' \
    "$(qemu_render_command_cmd)"

# --- QEMU display scaling ---------------------------------------------------
qemu_mock_tmp=$(mktemp -d)
qemu_mock="$qemu_mock_tmp/qemu-system-i386"
# shellcheck disable=SC2016 # The mock reads QEMU_MOCK_VERSION at execution time.
printf '#!/usr/bin/env bash\nprintf "QEMU emulator version %%s\\n" "$QEMU_MOCK_VERSION"\n' >"$qemu_mock"
chmod +x "$qemu_mock"
# shellcheck disable=SC2034 # Read by qemu_version_major through QEMU_SYSTEM.
QEMU_SYSTEM=$qemu_mock

export QEMU_MOCK_VERSION=11.0.0
QEMU_DISPLAY="-display cocoa"
qemu_configure_display_scaling
assert_eq "display/cocoa-qemu11" "-display cocoa,zoom-to-fit=on,zoom-interpolation=on" "$QEMU_DISPLAY"

export QEMU_MOCK_VERSION=10.1.0
QEMU_DISPLAY="-display cocoa"
qemu_configure_display_scaling
assert_eq "display/cocoa-qemu10" "-display cocoa" "$QEMU_DISPLAY"

export QEMU_MOCK_VERSION=11.0.0
QEMU_DISPLAY="-display gtk"
qemu_configure_display_scaling
assert_eq "display/gtk-qemu11" "-display gtk" "$QEMU_DISPLAY"

rm -rf "$qemu_mock_tmp"

# --- install script fdisk prompt helpers ------------------------------------
assert_eq "script/fdisk-range-first" "1 1015" "$(script_fdisk_parse_range "First cylinder (1-1015):   ")"
assert_eq "script/fdisk-range-last" "131 1015" "$(script_fdisk_parse_range "Last cylinder or +size or +sizeM or +sizeK (131-1015): ")"
assert_eq "script/fdisk-range-default" "131 1015" "$(script_fdisk_parse_range "First cylinder (131-1015, default 131): ")"
assert_eq "script/fdisk-range-bracketed" "1 520" "$(script_fdisk_parse_range "Last cylinder or +size or +sizeM or +sizeK ([1]-520): ")"
assert_fail "script/fdisk-range-answered" script_fdisk_parse_range "First cylinder (1-1015): 1"
assert_fail "script/fdisk-range-missing" script_fdisk_parse_range "no fdisk prompt here"

wait_screen="ready"
# shellcheck disable=SC2329 # Invoked indirectly by script_wait_until.
qmp_qemu_running() { return 0; }
# shellcheck disable=SC2329 # Invoked indirectly by script_wait_until.
qmp_vga_dump_text() { printf '%s\n' "$wait_screen"; }
# shellcheck disable=SC2329 # Invoked indirectly by script_send_line via script_prompt.
qmp_send_string() { return 0; }
# shellcheck disable=SC2329 # Invoked indirectly by script_send_line via script_prompt.
qmp_sendkey() { return 0; }
wait_output=$(script_wait_until script_screen_contains_string "ready")
wait_status=$?
assert_eq "script/wait-single-status" "0" "$wait_status"
assert_eq "script/wait-single-output" "ready" "$wait_output"
wait_output=$(script_wait_string "ready")
tests_run=$((tests_run + 1))
case "$wait_output" in
*"🖥️  ready"*) ;;
*)
    tests_failed=$((tests_failed + 1))
    printf "FAIL script/wait-string-output\n  actual:   [%s]\n" "$wait_output"
    ;;
esac

wait_screen="fatal error"
wait_output=$(script_wait_until \
    script_screen_contains_string "fatal error" \
    script_screen_contains_string "all done" \
    --)
wait_status=$?
assert_eq "script/wait-multi-status" "0" "$wait_status"
assert_eq "script/wait-multi-output" "fatal error" "$wait_output"

wait_screen="all done"
wait_output=$(script_wait_until \
    script_screen_contains_string "fatal error" \
    script_screen_contains_string "all done" \
    --)
wait_status=$?
assert_eq "script/wait-multi-second-status" "1" "$wait_status"
assert_eq "script/wait-multi-second-output" "all done" "$wait_output"

wait_output_tmp=$(mktemp)
script_wait_alternative -e "fatal error" "all done" >"$wait_output_tmp"
wait_status=$?
wait_output=$(cat "$wait_output_tmp")
rm -f "$wait_output_tmp"
assert_eq "script/wait-alternative-status" "1" "$wait_status"
assert_eq "script/wait-alternative-output" \
    "🔀 Awaiting 2 alternatives... matched #1
🖥️  all done" \
    "$wait_output"

wait_screen="prefix all done suffix
exact line"
wait_output_tmp=$(mktemp)
script_wait_alternative -e -l "all done" "exact line" >"$wait_output_tmp"
wait_status=$?
wait_output=$(cat "$wait_output_tmp")
rm -f "$wait_output_tmp"
assert_eq "script/wait-alternative-line-status" "1" "$wait_status"
assert_eq "script/wait-alternative-line-output" \
    "🔀 Awaiting 2 alternatives... matched #1
🖥️  exact line" \
    "$wait_output"

wait_output_tmp=$(mktemp)
script_wait_alternative -l "all done" "exact line" >"$wait_output_tmp"
wait_status=$?
wait_output=$(cat "$wait_output_tmp")
rm -f "$wait_output_tmp"
assert_eq "script/wait-alternative-quiet-status" "1" "$wait_status"
assert_eq "script/wait-alternative-quiet-output" \
    "🔀 Awaiting 2 alternatives... matched #1" \
    "$wait_output"

wait_screen="first line
second line"
wait_output_tmp=$(mktemp)
script_wait_line "first line" "second line" >"$wait_output_tmp"
wait_status=$?
wait_output=$(cat "$wait_output_tmp")
rm -f "$wait_output_tmp"
assert_eq "script/wait-line-sequence-status" "0" "$wait_status"
assert_eq "script/wait-line-sequence-output" \
    "⏳ first line🖥️  first line[K
⏳ second line🖥️  second line[K" \
    "$wait_output"

# --- regex matcher -----------------------------------------------------------
# Patterns are extended regexes (grep -E), so escaped parens match literally,
# matching the style used by dialog_answer -r callers.
regex_screen="Slackware Linux Setup (version 3.4)"
assert_ok "script/screen-contains-regex" script_screen_contains_regex "$regex_screen" "Setup \(version .*\)"
assert_fail "script/screen-contains-regex-miss" script_screen_contains_regex "$regex_screen" "Setup \(build .*\)"

wait_screen="Slackware Linux Setup (version 3.4)"
wait_output_tmp=$(mktemp)
script_wait_string -r "version [0-9.]*" >"$wait_output_tmp"
wait_status=$?
wait_output=$(cat "$wait_output_tmp")
rm -f "$wait_output_tmp"
assert_eq "script/wait-string-regex-status" "0" "$wait_status"
tests_run=$((tests_run + 1))
case "$wait_output" in
*"🖥️  version [0-9.]*"*) ;;
*)
    tests_failed=$((tests_failed + 1))
    printf "FAIL script/wait-string-regex-output\n  actual:   [%s]\n" "$wait_output"
    ;;
esac

wait_output_tmp=$(mktemp)
script_wait_line -r "Setup \(version .*\)" >"$wait_output_tmp"
wait_status=$?
rm -f "$wait_output_tmp"
assert_eq "script/wait-line-regex-status" "0" "$wait_status"

wait_output_tmp=$(mktemp)
script_wait_alternative -e -r "no match here" "version [0-9.]*" >"$wait_output_tmp"
wait_status=$?
wait_output=$(cat "$wait_output_tmp")
rm -f "$wait_output_tmp"
assert_eq "script/wait-alternative-regex-status" "1" "$wait_status"
assert_eq "script/wait-alternative-regex-output" \
    "🔀 Awaiting 2 alternatives... matched #1
🖥️  version [0-9.]*" \
    "$wait_output"

wait_output_tmp=$(mktemp)
script_prompt -r "Setup \(version .*\)" "answer" >"$wait_output_tmp"
wait_status=$?
rm -f "$wait_output_tmp"
assert_eq "script/prompt-regex-status" "0" "$wait_status"

# --- dialog_case ---------------------------------------------------------
# shellcheck source=/dev/null
source "$REPO_ROOT/slackware/dialog-setup.sh"

case_tmp=$(mktemp -d)
echo 0 >"$case_tmp/state"
: >"$case_tmp/answers"

# The fake console raises screens in the reverse of the listed order, advances
# to the next screen whenever an answer is sent, and ends on the terminator.
# shellcheck disable=SC2329 # Invoked indirectly by script_wait_until.
qmp_vga_dump_text() {
    case "$(cat "$case_tmp/state")" in
    0) printf 'TITLE: SECOND\nRESPONSE:\n' ;;
    1) printf 'TITLE: FIRST\nRESPONSE:\n' ;;
    *) printf 'TITLE: DONE\nRESPONSE:\n' ;;
    esac
}
# shellcheck disable=SC2329 # Invoked indirectly by script_send_line via dialog_answer.
qmp_send_string() {
    printf '%s\n' "$1" >>"$case_tmp/answers"
    echo "$(($(cat "$case_tmp/state") + 1))" >"$case_tmp/state"
}

# Handlers receive the matched title as their only argument and answer the
# screen themselves; the terminator returns immediately, leaving it
# unanswered along with any titles that were never asked.
# shellcheck disable=SC2329 # Invoked indirectly by dialog_case.
case_echo_title() { dialog_answer "$1" "$1"; }
dialog_case \
    "FIRST" case_echo_title \
    "SECOND" case_echo_title \
    "NEVER ASKED" case_echo_title \
    "DONE" >/dev/null
wait_status=$?
assert_eq "dialog/case-status" "0" "$wait_status"
assert_eq "dialog/case-out-of-order" "SECOND
FIRST" "$(cat "$case_tmp/answers")"

# dialog_answer_any takes TITLE ANSWER pairs and answers them directly, in
# whatever order the screens appear, until the terminator shows up.
echo 0 >"$case_tmp/state"
: >"$case_tmp/answers"
dialog_answer_any "FIRST" "one" "SECOND" "two" "DONE" >/dev/null
wait_status=$?
assert_eq "dialog/answer-status" "0" "$wait_status"
assert_eq "dialog/answer-out-of-order" "two
one" "$(cat "$case_tmp/answers")"

# A repeated title is handled once per occurrence, in the order listed.
echo 0 >"$case_tmp/state"
: >"$case_tmp/answers"
# shellcheck disable=SC2329 # Invoked indirectly by script_wait_until.
qmp_vga_dump_text() {
    if [ "$(cat "$case_tmp/state")" -lt 2 ]; then
        printf 'TITLE: REPEAT\nRESPONSE:\n'
    else
        printf 'TITLE: DONE\nRESPONSE:\n'
    fi
}
# shellcheck disable=SC2329 # Invoked indirectly by dialog_case.
case_answer_one() { dialog_answer "$1" "one"; }
# shellcheck disable=SC2329 # Invoked indirectly by dialog_case.
case_answer_two() { dialog_answer "$1" "two"; }
dialog_case "REPEAT" case_answer_one "REPEAT" case_answer_two "DONE" >/dev/null
assert_eq "dialog/case-repeat" "one
two" "$(cat "$case_tmp/answers")"
rm -rf "$case_tmp"

# Restore the simple screen mocks for any later screen-driven tests.
# shellcheck disable=SC2329 # Invoked indirectly by script_wait_until.
qmp_vga_dump_text() { printf '%s\n' "$wait_screen"; }
# shellcheck disable=SC2329 # Invoked indirectly by script_send_line.
qmp_send_string() { return 0; }

# --- extract image links ----------------------------------------------------
extract_tmp=$(mktemp -d)
printf 'boot image\n' >"$extract_tmp/boot.img"
(cd "$extract_tmp" && retro_link_boot_root boot.img)
assert_eq "extract/boot-img-stays-file" "regular file" "$(cd "$extract_tmp" && if [ -f boot.img ] && [ ! -L boot.img ]; then printf 'regular file'; else printf 'other'; fi)"

printf 'kernel image\n' >"$extract_tmp/bare.i"
(cd "$extract_tmp" && retro_link_boot_root bare.i)
assert_eq "extract/boot-img-links-other-name" "bare.i" "$(readlink "$extract_tmp/boot.img")"
rm -rf "$extract_tmp"

# --- Red Hat Kickstart floppy staging ---------------------------------------
if command -v mcopy >/dev/null 2>&1 && command -v mformat >/dev/null 2>&1 && command -v mtype >/dev/null 2>&1; then
    rh_tmp=$(mktemp -d)
    mkdir -p "$rh_tmp/redhat/5.0-infomagic" "$rh_tmp/qemu.d"
    printf '# comment\n\nkickstart\n  # indented comment\n  \n' >"$rh_tmp/redhat/5.0-infomagic/ks.cfg"
    truncate -s 1440k "$rh_tmp/qemu.d/boot.img"
    mformat -i "$rh_tmp/qemu.d/boot.img" ::
    (
        CONFDIR="$rh_tmp/redhat/5.0-infomagic"
        CONFNAME=redhat/5.0-infomagic
        redhat_stage_kickstart "$rh_tmp/qemu.d/boot.img"
    )
    assert_eq "redhat/ks.cfg" "kickstart" "$(mtype -i "$rh_tmp/qemu.d/boot.img" ::ks.cfg | tr -d '\r\n')"
    rm -rf "$rh_tmp"

    rh_tmp=$(mktemp -d)
    mkdir -p "$rh_tmp/redhat/5.2-infomagic" "$rh_tmp/qemu.d"
    printf '# comment\n\ncreated\n' >"$rh_tmp/redhat/5.2-infomagic/ks.cfg"
    (
        # shellcheck disable=SC2034 # Read indirectly by redhat_stage_kickstart.
        CONFDIR="$rh_tmp/redhat/5.2-infomagic"
        # shellcheck disable=SC2034 # Read indirectly by redhat_stage_kickstart.
        CONFNAME=redhat/5.2-infomagic
        redhat_stage_kickstart "$rh_tmp/qemu.d/boot.img"
    )
    assert_eq "redhat/ks.cfg-missing-boot-image" "missing" "$(if [ -e "$rh_tmp/qemu.d/boot.img" ]; then printf 'exists'; else printf 'missing'; fi)"
    rm -rf "$rh_tmp"
fi

# --- slackware tagfile rules ------------------------------------------------
tagstate() { awk -v p="$2:" '$1 == p { print $2 }' "$1"; }

# Two-pass application of *.tag rules over staged series tagfiles.
slack_tmp=$(mktemp -d)
mkdir -p "$slack_tmp/conf" "$slack_tmp/fat/a1" "$slack_tmp/fat/x1" "$slack_tmp/fat/xap1"
touch "$slack_tmp/fat/a1/bash.tgz" "$slack_tmp/fat/a1/sed.tgz" "$slack_tmp/fat/a1/scsi.tgz"
touch "$slack_tmp/fat/x1/xbin.tgz" "$slack_tmp/fat/x1/xvga16.tgz" "$slack_tmp/fat/x1/xs3.tgz"
touch "$slack_tmp/fat/xap1/ghostscript.tgz"
# Override is listed *before* its wildcard to prove the two-pass design makes
# specific entries win regardless of in-file order.
printf 'a bash ADD\na * SKP\nx * ADD\nx xvga16 SKP\nxap * ADD\n' >"$slack_tmp/conf/max.tag"

(cd "$slack_tmp" && CONFDIR="$slack_tmp/conf" TEMPDIR="$slack_tmp" INSTALL_TAGSETS=max slackware_prepare_tagfiles)

assert_eq "tag/wildcard-skp"       "SKP" "$(tagstate "$slack_tmp/fat/a1/tagfile" sed)"
assert_eq "tag/wildcard-skp2"      "SKP" "$(tagstate "$slack_tmp/fat/a1/tagfile" scsi)"
assert_eq "tag/override-beats-wc"  "ADD" "$(tagstate "$slack_tmp/fat/a1/tagfile" bash)"
assert_eq "tag/x-wildcard-add"     "ADD" "$(tagstate "$slack_tmp/fat/x1/tagfile" xbin)"
assert_eq "tag/x-wildcard-add2"    "ADD" "$(tagstate "$slack_tmp/fat/x1/tagfile" xs3)"
assert_eq "tag/x-override-skp"     "SKP" "$(tagstate "$slack_tmp/fat/x1/tagfile" xvga16)"
# x* rules must not bleed into the xap series (prefix-match isolation).
assert_eq "tag/series-isolation"   "ADD" "$(tagstate "$slack_tmp/fat/xap1/tagfile" ghostscript)"

# Direct coverage of generated tagfiles for a single series.
slack_tmp2=$(mktemp -d)
mkdir -p "$slack_tmp2/fat/n1"
touch "$slack_tmp2/fat/n1/tcpip.tgz" "$slack_tmp2/fat/n1/bind.tgz"
touch "$slack_tmp2/none.tag"
(cd "$slack_tmp2" && CONFDIR="$slack_tmp2" TEMPDIR="$slack_tmp2" INSTALL_TAGSETS=none slackware_prepare_tagfiles)
assert_eq "series/default-skp"        "SKP" "$(tagstate "$slack_tmp2/fat/n1/tagfile" tcpip)"
assert_eq "series/default-skp2"       "SKP" "$(tagstate "$slack_tmp2/fat/n1/tagfile" bind)"
rm -rf "$slack_tmp" "$slack_tmp2"

# --- summary ----------------------------------------------------------------
echo
if [ "$tests_failed" -eq 0 ]; then
    echo "OK: $tests_run assertions passed."
    exit 0
fi
echo "FAILED: $tests_failed of $tests_run assertions failed."
exit 1
