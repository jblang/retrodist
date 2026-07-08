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
source "$REPO_ROOT/retrolib/serial.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/retrolib/fdisk.sh"
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
# shellcheck disable=SC2329 # Invoked indirectly by screen_wait.
qmp_qemu_running() { return 0; }
# shellcheck disable=SC2329 # Invoked indirectly by screen_wait.
qmp_vga_dump_text() { printf '%s\n' "$wait_screen"; }
# shellcheck disable=SC2329 # Invoked indirectly by kb_send_line.
qmp_send_string() { return 0; }
# shellcheck disable=SC2329 # Invoked indirectly by kb_send_line.
qmp_sendkey() { return 0; }
wait_output=$(screen_wait "ready")
wait_status=$?
assert_eq "script/wait-string-status" "0" "$wait_status"
tests_run=$((tests_run + 1))
case "$wait_output" in
*"🖥️  ready"*) ;;
*)
    tests_failed=$((tests_failed + 1))
    printf "FAIL script/wait-string-output\n  actual:   [%s]\n" "$wait_output"
    ;;
esac

wait_screen="first line
second line"
wait_output_tmp=$(mktemp)
screen_wait -l "first line" "second line" >"$wait_output_tmp"
wait_status=$?
wait_output=$(cat "$wait_output_tmp")
rm -f "$wait_output_tmp"
assert_eq "script/wait-line-sequence-status" "0" "$wait_status"
assert_eq "script/wait-line-sequence-output" \
    "⏳ first line🖥️  first line[K
⏳ second line🖥️  second line[K" \
    "$wait_output"

# --- serial regex matcher ----------------------------------------------------
# Patterns are extended regexes (grep -E), so escaped parens match literally,
# matching the style used by dialog_answer -r callers.
regex_screen="Slackware Linux Setup (version 3.4)"
assert_ok "serial/contains-regex" serial_contains_regex "$regex_screen" "Setup \(version .*\)"
assert_fail "serial/contains-regex-miss" serial_contains_regex "$regex_screen" "Setup \(build .*\)"

# --- dialog helpers ----------------------------------------------------------
# Dialog screens are seeded up front and answered through serial_send.
# shellcheck source=/dev/null
source "$REPO_ROOT/retrolib/dialog.sh"

case_tmp=$(mktemp -d)
SERIAL_LOG=$case_tmp/log
# shellcheck disable=SC2329 # Invoked indirectly by dialog helpers.
serial_send() { printf '%s\n' "$1" >>"$case_tmp/answers"; }
exec 4>&2 2>/dev/null

# Screens are answered in stream order; the terminator remains unanswered.
SERIAL_LINE=0
: >"$case_tmp/answers"
printf '%s\n' \
    'TITLE: SECOND' 'RESPONSE: ' \
    'TITLE: FIRST' 'RESPONSE: ' \
    'TITLE: DONE' 'RESPONSE: ' \
    >"$SERIAL_LOG"
# shellcheck disable=SC2329 # Invoked indirectly by dialog_case.
case_echo_title() { dialog_answer "$1" "" "$1"; }
dialog_case \
    any "FIRST" case_echo_title \
    any "SECOND" case_echo_title \
    any "NEVER ASKED" case_echo_title \
    any "DONE" >/dev/null
wait_status=$?
assert_eq "dialog/case-status" "0" "$wait_status"
assert_eq "dialog/case-out-of-order" "SECOND
FIRST" "$(cat "$case_tmp/answers")"

# dialog_answer_any directly answers matching TYPE TITLE ANSWER triples.
SERIAL_LINE=0
: >"$case_tmp/answers"
dialog_answer_any any "FIRST" "one" any "SECOND" "two" any "DONE" >/dev/null
wait_status=$?
assert_eq "dialog/answer-status" "0" "$wait_status"
assert_eq "dialog/answer-out-of-order" "two
one" "$(cat "$case_tmp/answers")"

# dialog_answer_any -t answers the marked pair and then returns.
SERIAL_LINE=0
: >"$case_tmp/answers"
printf '%s\n' \
    'TITLE: FIRST' 'RESPONSE: ' \
    'TITLE: DONE' 'RESPONSE: ' \
    'TITLE: SECOND' 'RESPONSE: ' \
    >"$SERIAL_LOG"
dialog_answer_any any "FIRST" "one" -t any "DONE" "done" any "SECOND" "two" >/dev/null
wait_status=$?
assert_eq "dialog/answer-terminal-status" "0" "$wait_status"
assert_eq "dialog/answer-terminal" "one
done" "$(cat "$case_tmp/answers")"

# dialog_answer_any handles repeated type/title alternatives in listed order.
SERIAL_LINE=0
: >"$case_tmp/answers"
printf '%s\n' \
    'TITLE: CHOOSE PARTITION' 'TYPE: inputbox' 'RESPONSE: ' \
    'TITLE: CHOOSE PARTITION' 'TYPE: inputbox' 'RESPONSE: ' \
    'TITLE: NEVER' 'TYPE: inputbox' 'RESPONSE: ' \
    >"$SERIAL_LOG"
dialog_answer_any \
    inputbox "CHOOSE PARTITION" "/dev/hdb1" \
    -t inputbox "CHOOSE PARTITION" q \
    inputbox "NEVER" "unused" >/dev/null
wait_status=$?
assert_eq "dialog/answer-repeat-terminal-status" "0" "$wait_status"
assert_eq "dialog/answer-repeat-terminal" "/dev/hdb1
q" "$(cat "$case_tmp/answers")"

# dialog_answer_any treats msgbox and textbox as interchangeable.
SERIAL_LINE=0
: >"$case_tmp/answers"
printf '%s\n' \
    'TITLE: SWAP SPACE CONFIGURED' 'TYPE: textbox' 'RESPONSE: ' \
    'TITLE: DONE' 'TYPE: msgbox' 'RESPONSE: ' \
    >"$SERIAL_LOG"
dialog_answer_any \
    msgbox "SWAP SPACE CONFIGURED" ok \
    msgbox "DONE" >/dev/null
wait_status=$?
assert_eq "dialog/answer-textbox-status" "0" "$wait_status"
assert_eq "dialog/answer-textbox" "ok" "$(cat "$case_tmp/answers")"

# A repeated title is handled once per occurrence, in the order listed.
SERIAL_LINE=0
: >"$case_tmp/answers"
printf '%s\n' \
    'TITLE: REPEAT' 'RESPONSE: ' \
    'TITLE: REPEAT' 'RESPONSE: ' \
    'TITLE: DONE' 'RESPONSE: ' \
    >"$SERIAL_LOG"
# shellcheck disable=SC2329 # Invoked indirectly by dialog_case.
case_answer_one() { dialog_answer "$1" "" "one"; }
# shellcheck disable=SC2329 # Invoked indirectly by dialog_case.
case_answer_two() { dialog_answer "$1" "" "two"; }
dialog_case any "REPEAT" case_answer_one any "REPEAT" case_answer_two any "DONE" >/dev/null
assert_eq "dialog/case-repeat" "one
two" "$(cat "$case_tmp/answers")"

# dialog_case can distinguish screens that share a title but have different types.
SERIAL_LINE=0
: >"$case_tmp/answers"
printf '%s\n' \
    'TITLE: MODEM CONFIGURATION' 'TYPE: menu' 'RESPONSE: ' \
    'TITLE: DONE' 'TYPE: msgbox' 'RESPONSE: ' \
    >"$SERIAL_LOG"
# shellcheck disable=SC2329 # Invoked indirectly by dialog_case.
case_answer_yesno() { dialog_answer "$1" yesno "no"; }
# shellcheck disable=SC2329 # Invoked indirectly by dialog_case.
case_answer_menu() { dialog_answer "$1" menu "no modem"; }
dialog_case \
    yesno "MODEM CONFIGURATION" case_answer_yesno \
    menu "MODEM CONFIGURATION" case_answer_menu \
    msgbox "DONE" >/dev/null
assert_eq "dialog/case-type" "no modem" "$(cat "$case_tmp/answers")"

# dialog_case -t answers the marked screen and then returns.
SERIAL_LINE=0
: >"$case_tmp/answers"
printf '%s\n' \
    'TITLE: FIRST' 'TYPE: msgbox' 'RESPONSE: ' \
    'TITLE: DONE' 'TYPE: msgbox' 'RESPONSE: ' \
    'TITLE: SECOND' 'TYPE: msgbox' 'RESPONSE: ' \
    >"$SERIAL_LOG"
dialog_case \
    msgbox "FIRST" case_echo_title \
    -t msgbox "DONE" case_echo_title \
    msgbox "SECOND" case_echo_title >/dev/null
assert_eq "dialog/case-terminal" "FIRST
DONE" "$(cat "$case_tmp/answers")"

# Typed wrappers wait for TYPE/TEXT lines before answering.
SERIAL_LINE=0
: >"$case_tmp/answers"
printf '%s\n' \
    'TITLE: Installation Type' 'TYPE: menu' 'TEXT: Which do you prefer?' 'RESPONSE: ' \
    >"$SERIAL_LOG"
dialog_menu "Installation Type" "Which do you prefer?" cdrom >/dev/null
assert_eq "dialog/menu-wrapper" "cdrom" "$(cat "$case_tmp/answers")"

# dialog_menu_text selects the key for the item whose displayed text matches.
SERIAL_LINE=0
: >"$case_tmp/answers"
printf '%s\n' \
    'TITLE: SOURCE MEDIA SELECTION' \
    'TYPE: menu' \
    'ITEM: 1 :: Install from a Slackware CD-ROM' \
    'ITEM: 2 :: Install from a hard drive partition' \
    'RESPONSE: ' \
    >"$SERIAL_LOG"
dialog_menu_text "SOURCE MEDIA SELECTION" "CD-ROM" >/dev/null
assert_eq "dialog/menu-text" "1" "$(cat "$case_tmp/answers")"

# dialog_menu_text -r matches item text as an extended regex.
SERIAL_LINE=0
: >"$case_tmp/answers"
printf '%s\n' \
    'TITLE: Install from the Slackware CD-ROM' \
    'TYPE: menu' \
    'ITEM: 1 :: SCSI (/dev/scd0 or /dev/scd1)' \
    'ITEM: 7 :: Most IDE-interface CD drives' \
    'RESPONSE: ' \
    >"$SERIAL_LOG"
dialog_menu_text -r "Install from the Slackware CD-ROM" "IDE.*CD drives" >/dev/null
assert_eq "dialog/menu-text-regex" "7" "$(cat "$case_tmp/answers")"

# dialog_answer_any -s matches keys as plain substrings.
SERIAL_LINE=0
: >"$case_tmp/answers"
printf '%s\n' \
    'TITLE: Network Configuration' 'TEXT: What is the netmask?' 'RESPONSE: ' \
    'TITLE: Network Configuration' 'TEXT: What is the network address?' 'RESPONSE: ' \
    'TITLE: Net Config' 'TEXT: Is this correct?' 'RESPONSE: ' \
    >"$SERIAL_LOG"
dialog_answer_any -s \
    any "What is the network address?" "10.0.2.0" \
    any "What is the netmask?" "255.255.255.0" \
    any "Is this correct?" >/dev/null
wait_status=$?
assert_eq "dialog/answer-any-substring-status" "0" "$wait_status"
assert_eq "dialog/answer-any-substring" "255.255.255.0
10.0.2.0" "$(cat "$case_tmp/answers")"
exec 2>&4 4>&-
rm -rf "$case_tmp"

# --- serial transport --------------------------------------------------------
# Restore the real serial helpers after dialog tests mocked serial_send.
# shellcheck source=/dev/null
source "$REPO_ROOT/retrolib/script.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/retrolib/serial.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/retrolib/fdisk.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/retrolib/dialog.sh"
serial_tmp=$(mktemp -d)
SERIAL_LOG=$serial_tmp/log
SERIAL_LINE=0
SERIAL_TRANSCRIPT_LINE=0

# Transcript order: received text, matched waits, then transmitted text.
printf '%s\n' 'noise' 'MATCH' 'late' >"$SERIAL_LOG"
exec 9>"$serial_tmp/input"
serial_wait_one text_contains_line "MATCH" >/dev/null 2>"$serial_tmp/transcript"
serial_send "typed" 2>>"$serial_tmp/transcript"
printf '%s\n' 'typed' 'DONE' >>"$SERIAL_LOG"
serial_wait_one text_contains_line "DONE" >/dev/null 2>>"$serial_tmp/transcript"
assert_eq "serial/transcript" "➡️  noise
✅ MATCH
➡️  late
⬅️  typed
✅ DONE" "$(cat "$serial_tmp/transcript")"
assert_eq "serial/transcript-input" "typed" "$(cat "$serial_tmp/input")"
exec 9>&-

# serial_shell starts a screen-launched shell redirected to serial.
SERIAL_LOG=$serial_tmp/shell
SERIAL_LINE=0
SERIAL_TRANSCRIPT_LINE=0
# shellcheck disable=SC2034 # Read by serial_shell_start.
SERIAL_SHELL_PROMPT="SERIAL#"
# shellcheck disable=SC2034 # Read by serial_shell_start.
SERIAL_SHELL_DEV=/dev/ttyS2
wait_screen="#"
qmp_strings=
# shellcheck disable=SC2329 # Invoked indirectly by serial_shell.
qmp_send_string() { qmp_strings="${qmp_strings}${qmp_strings:+
}$1"; }
# shellcheck disable=SC2329 # Invoked indirectly by serial_shell.
qmp_sendkey() { return 0; }
printf '%s\n' \
    'SERIAL# ' \
    'one' \
    'SERIAL# ' \
    'two' \
    'stderr' \
    'SERIAL# ' \
    >"$SERIAL_LOG"
: >"$serial_tmp/shell-input"
exec 9>"$serial_tmp/shell-input"
serial_shell "echo one" "echo two >&2" >/dev/null 2>/dev/null
assert_eq "serial/shell-launcher" "[ -c /dev/ttyS2 ] || mknod /dev/ttyS2 c 4 67; PS1='SERIAL# ' sh -i </dev/ttyS2 >/dev/ttyS2 2>&1" "$qmp_strings"
assert_eq "serial/shell-input" "echo one
echo two >&2
exit" "$(cat "$serial_tmp/shell-input")"
exec 9>&-
unset SERIAL_SHELL_PROMPT SERIAL_SHELL_DEV

SERIAL_LOG=$serial_tmp/shell-nowait
SERIAL_LINE=0
SERIAL_TRANSCRIPT_LINE=0
qmp_strings=
printf '%s\n' '# ' >"$SERIAL_LOG"
: >"$serial_tmp/shell-nowait-input"
exec 9>"$serial_tmp/shell-nowait-input"
serial_shell --no-wait "long-running install" >/dev/null 2>/dev/null
assert_eq "serial/shell-nowait-input" "long-running install" "$(cat "$serial_tmp/shell-nowait-input")"
exec 9>&-

SERIAL_LINE=0
SERIAL_TRANSCRIPT_LINE=0
exec 3>&2 2>/dev/null

# A prompt blocks without a trailing newline, so the partial line matches too.
printf 'TITLE: Foo\nRESPONSE: ' >"$SERIAL_LOG"
serial_wait_one text_contains_line "TITLE: Foo" >/dev/null
assert_eq "serial/title-consumed" "TITLE: Foo" "$SERIAL_MATCHED_TEXT"
serial_wait_one text_contains_line "RESPONSE:" >/dev/null
assert_eq "serial/partial-consumed" "RESPONSE: " "$SERIAL_MATCHED_TEXT"

# Consumed text never matches again; a fresh occurrence does.
assert_fail "serial/no-rematch" serial_scan text_contains_line "TITLE: Foo"
printf '\nTITLE: Foo\n' >>"$SERIAL_LOG"
serial_wait_one text_contains_line "TITLE: Foo" >/dev/null
assert_eq "serial/second-occurrence" "TITLE: Foo" "$SERIAL_MATCHED_TEXT"

# Consuming a partial prompt must not hide later text on the same line.
SERIAL_LOG=$serial_tmp/appended-prompt
SERIAL_LINE=0
# shellcheck disable=SC2034 # Read by serial_scan.
SERIAL_TRANSCRIPT_LINE=0
printf 'Command (m for help): ' >"$SERIAL_LOG"
serial_wait_one text_contains_line "Command (m for help):" >/dev/null
printf 't\r\nPartition number (1-4): ' >>"$SERIAL_LOG"
serial_wait_one text_contains_line "Partition number (1-4):" >/dev/null
assert_eq "serial/appended-prompt" "Partition number (1-4): " "$SERIAL_MATCHED_TEXT"

# Alternatives match in stream order, not argument order.
printf 'beta\nalpha\n' >>"$SERIAL_LOG"
serial_wait_until \
    text_contains_string "alpha" \
    text_contains_string "beta" \
    -- >"$serial_tmp/matched"
wait_status=$?
assert_eq "serial/stream-order-status" "1" "$wait_status"
assert_eq "serial/stream-order-text" "beta" "$(cat "$serial_tmp/matched")"

# Dialog answers go through serial_send instead of the console keyboard path.
# shellcheck disable=SC2329 # Invoked indirectly by dialog helpers.
serial_send() { printf '%s\n' "$1" >>"$serial_tmp/answers"; }
printf 'TITLE: Serial Screen\nTYPE: menu\nRESPONSE: ' >>"$SERIAL_LOG"
dialog_answer "Serial Screen" menu "picked" >/dev/null
assert_eq "serial/dialog-answer" "picked" "$(cat "$serial_tmp/answers")"

# Terminator matches must remain available for the caller's next wait.
: >"$serial_tmp/answers"
printf '\nTITLE: Confirm\nTYPE: yesno\nTEXT: Is this correct?\nRESPONSE: ' >>"$SERIAL_LOG"
dialog_answer_any -s any "never asked" "unused" any "Is this correct?" >/dev/null
dialog_answer "Confirm" yesno "y" >/dev/null
assert_eq "serial/terminator-preserved" "y" "$(cat "$serial_tmp/answers")"

# dialog_case must only peek before its handler re-waits for the title.
: >"$serial_tmp/answers"
printf '\nTITLE: Handled\nTYPE: menu\nRESPONSE: \nTITLE: Done\nRESPONSE: \n' >>"$SERIAL_LOG"
# shellcheck disable=SC2329 # Invoked indirectly by dialog_case.
case_serial_answer() { dialog_answer "$1" menu "handled"; }
dialog_case menu "Handled" case_serial_answer any "Done" >/dev/null
assert_eq "serial/case-handler" "handled" "$(cat "$serial_tmp/answers")"

# Echoed answers and CRLF output do not confuse serial matching.
printf 'picked\r\nTITLE: After Echo\r\n' >>"$SERIAL_LOG"
serial_wait_one text_contains_line "TITLE: After Echo" >/dev/null
assert_eq "serial/echo-crlf-consumed" "TITLE: After Echo" "$SERIAL_MATCHED_TEXT"

# script_fdisk drives every fdisk prompt over the serial pipe; the shell
# prompt waits around it stay on the screen.
SERIAL_LOG=$serial_tmp/fdisk
# shellcheck disable=SC2034 # Read by script_fdisk through serial helpers.
SERIAL_LINE=0
: >"$serial_tmp/answers"
wait_screen="#"
printf '%s\n' \
    '# ' \
    'Command (m for help): ' \
    'Partition number (1-4): ' \
    'Command (m for help): ' \
    'Partition number (1-4): ' \
    'Command (m for help): ' \
    'Partition number (1-4): ' \
    '   First cylinder (1-1015): ' \
    'Last cylinder or +size or +sizeM or +sizeK (1-1015): ' \
    'Command (m for help): ' \
    'Partition number (1-4): ' \
    'First cylinder (131-1015, default 131): ' \
    'Last cylinder or +size or +sizeM or +sizeK ([131]-1015): ' \
    'Command (m for help): ' \
    'Partition number (1-4): ' \
    'Hex code (type L to list codes): ' \
    'Command (m for help): ' \
    'Partition number (1-4): ' \
    'Hex code (type L to list codes): ' \
    'Command (m for help): ' \
    'Command (m for help): ' \
    '# ' \
    >"$SERIAL_LOG"
script_fdisk /dev/hda 64 >"$serial_tmp/fdisk-out" 2>"$serial_tmp/fdisk-err"
assert_eq "fdisk/serial-status" "0" "$?"
assert_eq "fdisk/serial-answers" "fdisk /dev/hda
d
1
d
2
n
p
1
1
+64M
n
p
2
131
1015
t
1
82
t
2
83
p
w
exit" "$(cat "$serial_tmp/answers")"
tests_run=$((tests_run + 1))
case $(cat "$serial_tmp/fdisk-err") in
*"⏳"*|*"🖥️"*)
    tests_failed=$((tests_failed + 1))
    printf "FAIL fdisk/serial-log-no-screen-progress\n  actual:   [%s]\n" "$(cat "$serial_tmp/fdisk-err")"
    ;;
esac
exec 2>&3 3>&-

# --- dialog adapter serial routing -------------------------------------------
# The adapter sends screens and reads answers over DIALOG_SERIAL, and tees the
# transcript to the console for progress indication.
mkfifo "$serial_tmp/port"
exec 8<>"$serial_tmp/port"
printf 'ok\n' >&8
DIALOG_SERIAL=$serial_tmp/port sh "$REPO_ROOT/autoinst/dialog.sh" \
    --title Serial --msgbox hi 5 40 </dev/null >"$serial_tmp/console" 2>&1
assert_eq "adapter/serial-exit" "0" "$?"
IFS= read -r serial_line <&8 # divider
IFS= read -r serial_line <&8
assert_eq "adapter/serial-title" "TITLE: Serial" "$serial_line"
assert_ok "adapter/console-tee" grep -q "TITLE: Serial" "$serial_tmp/console"
exec 8<&-

# dialog.bak must not be used. Setup redirects dialog stderr into result files,
# so any real-dialog output there can corrupt responses.
cp "$REPO_ROOT/autoinst/dialog.sh" "$serial_tmp/dialog"
printf '#!/bin/sh\necho "VIEW $*"\n' >"$serial_tmp/dialog.bak"
chmod +x "$serial_tmp/dialog" "$serial_tmp/dialog.bak"
mkfifo "$serial_tmp/port2"
exec 8<>"$serial_tmp/port2"
printf 'ok\n' >&8
DIALOG_SERIAL=$serial_tmp/port2 sh "$serial_tmp/dialog" \
    --title Serial --msgbox hi 5 40 </dev/null >"$serial_tmp/view" 2>&1
assert_eq "adapter/view-exit" "0" "$?"
assert_fail "adapter/view-no-real-dialog" grep -q -- "VIEW " "$serial_tmp/view"
assert_ok "adapter/view-plaintext" grep -q "TITLE: Serial" "$serial_tmp/view"
exec 8<&-

# Setup redirects dialog stderr to result files such as /tmp/SeTtagpath, so
# stderr must carry exactly the answer even with a hostile dialog.bak present.
printf '#!/bin/sh\necho "VIEW $*" >&2\n' >"$serial_tmp/dialog.bak"
mkfifo "$serial_tmp/port4"
exec 8<>"$serial_tmp/port4"
printf '/retro/tagfiles\n' >&8
DIALOG_SERIAL=$serial_tmp/port4 bash "$serial_tmp/dialog" \
    --title Path --inputbox "tag path" 10 40 \
    </dev/null >/dev/null 2>"$serial_tmp/inputbox-result"
assert_eq "adapter/inputbox-stderr-result" "/retro/tagfiles" "$(cat "$serial_tmp/inputbox-result")"
exec 8<&-

mkfifo "$serial_tmp/port7"
exec 8<>"$serial_tmp/port7"
printf 'PATH\n' >&8
DIALOG_SERIAL=$serial_tmp/port7 bash "$serial_tmp/dialog" \
    --title Prompt --menu "mode" 10 40 2 NORMAL normal PATH path \
    </dev/null >/dev/null 2>"$serial_tmp/menu-path-result"
assert_eq "adapter/menu-stderr-result" "PATH" "$(cat "$serial_tmp/menu-path-result")"
exec 8<&-

# Display-only infobox widgets keep their requested text and dimensions on the
# console, do not call dialog.bak, and stay quiet on the serial transcript by
# default.
: >"$serial_tmp/infobox-serial"
DIALOG_SERIAL=$serial_tmp/infobox-serial sh "$serial_tmp/dialog" \
    --title Info --infobox "real progress" 7 50 </dev/null >"$serial_tmp/infobox" 2>&1
assert_eq "adapter/infobox-view-exit" "0" "$?"
assert_fail "adapter/infobox-no-real-dialog" grep -q -- "VIEW " "$serial_tmp/infobox"
assert_ok "adapter/infobox-console" grep -q -- "TITLE: Info" "$serial_tmp/infobox"
assert_eq "adapter/infobox-serial-muted" "" "$(cat "$serial_tmp/infobox-serial")"

: >"$serial_tmp/infobox-serial-unmuted"
DIALOG_SERIAL_INFOBOXES=1 DIALOG_SERIAL=$serial_tmp/infobox-serial-unmuted sh "$serial_tmp/dialog" \
    --title Info --infobox "real progress" 7 50 </dev/null >"$serial_tmp/infobox-unmuted" 2>&1
assert_eq "adapter/infobox-unmuted-exit" "0" "$?"
assert_ok "adapter/infobox-serial-unmuted" grep -q "TITLE: Info" "$serial_tmp/infobox-serial-unmuted"

# Match real dialog status codes for accepted, negative, and escape answers.
mkfifo "$serial_tmp/port5"
exec 8<>"$serial_tmp/port5"
printf 'no\n' >&8
DIALOG_SERIAL=$serial_tmp/port5 sh "$serial_tmp/dialog" \
    --yesno "continue?" 6 40 </dev/null >/dev/null 2>&1
assert_eq "adapter/yesno-no-exit" "1" "$?"
exec 8<&-

mkfifo "$serial_tmp/port6"
exec 8<>"$serial_tmp/port6"
printf 'esc\n' >&8
DIALOG_SERIAL=$serial_tmp/port6 sh "$serial_tmp/dialog" \
    --menu "pick" 10 40 2 first one second two </dev/null >/dev/null 2>&1
assert_eq "adapter/menu-esc-exit" "255" "$?"
exec 8<&-

# Empty menu response selects the highlighted item, like real dialog.
# Run under bash because macOS sh handles echo -n differently.
mkfifo "$serial_tmp/port3"
exec 8<>"$serial_tmp/port3"
printf '\n' >&8
DIALOG_SERIAL=$serial_tmp/port3 bash "$REPO_ROOT/autoinst/dialog.sh" \
    --menu "pick" 10 40 2 first one second two \
    </dev/null >/dev/null 2>"$serial_tmp/menu-result"
assert_eq "adapter/menu-empty-default" "first" "$(cat "$serial_tmp/menu-result")"
exec 8<&-
rm -rf "$serial_tmp"

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
printf 'a bash ADD # GNU bash shell\nx xbin OPT # X11 binaries\n' >"$slack_tmp/conf/default.tag"

(cd "$slack_tmp" && CONFDIR="$slack_tmp/conf" TEMPDIR="$slack_tmp" INSTALL_TAGSETS=max slackware_prepare_tagfiles)

assert_eq "tag/wildcard-skp"       "SKP" "$(tagstate "$slack_tmp/fat/a1/tagfile" sed)"
assert_eq "tag/wildcard-skp2"      "SKP" "$(tagstate "$slack_tmp/fat/a1/tagfile" scsi)"
assert_eq "tag/override-beats-wc"  "ADD" "$(tagstate "$slack_tmp/fat/a1/tagfile" bash)"
assert_eq "tag/x-wildcard-add"     "ADD" "$(tagstate "$slack_tmp/fat/x1/tagfile" xbin)"
assert_eq "tag/x-wildcard-add2"    "ADD" "$(tagstate "$slack_tmp/fat/x1/tagfile" xs3)"
assert_eq "tag/x-override-skp"     "SKP" "$(tagstate "$slack_tmp/fat/x1/tagfile" xvga16)"
# x* rules must not bleed into the xap series (prefix-match isolation).
assert_eq "tag/series-isolation"   "ADD" "$(tagstate "$slack_tmp/fat/xap1/tagfile" ghostscript)"

# ISO package lists feed PATH-mode custom tagfiles. Old color setup help says
# the first disk is enough, but cpkgtool actually checks the current disk
# directory name, so each disk directory needs a tagfile for packages on that
# disk.
slack_iso_tmp=$(mktemp -d)
cat >"$slack_iso_tmp/packages.txt" <<'EOF'
slakware/a1/bash.tgz
slakware/a2/lilo.tgz
slakware/a3/getty.tgz
slakware/ap1/mc.tgz
slakware/ap2/ghostscript.tgz
EOF
(
    SLACKWARE_PKGLIST="$slack_iso_tmp/packages.txt"
    slackware_universe_from_iso
) >"$slack_iso_tmp/universe"
assert_ok "tag/iso-first-a-disk" grep -q $'fat/tagfiles/a1/tagfile\ta\tbash' "$slack_iso_tmp/universe"
assert_ok "tag/iso-later-a-disk-currentdir" grep -q $'fat/tagfiles/a3/tagfile\ta\tgetty' "$slack_iso_tmp/universe"
assert_ok "tag/iso-first-ap-disk" grep -q $'fat/tagfiles/ap1/tagfile\tap\tmc' "$slack_iso_tmp/universe"
assert_ok "tag/iso-later-ap-disk-currentdir" grep -q $'fat/tagfiles/ap2/tagfile\tap\tghostscript' "$slack_iso_tmp/universe"
assert_fail "tag/iso-no-cross-disk-duplication" grep -q $'fat/tagfiles/a3/tagfile\ta\tbash' "$slack_iso_tmp/universe"
rm -rf "$slack_iso_tmp"

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
