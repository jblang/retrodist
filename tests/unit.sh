#!/usr/bin/env bash
# Unit tests for the pure shell helpers used by retro.
set -uo pipefail

REPO_D=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

# shellcheck source=/dev/null
source "$REPO_D/hostlib/logging.sh"
# shellcheck source=/dev/null
source "$REPO_D/hostlib/download.sh"
for qemu_lib in "$REPO_D"/hostlib/qemu*.sh; do
    # shellcheck source=/dev/null
    source "$qemu_lib"
done
# shellcheck source=/dev/null
source "$REPO_D/hostlib/qmp.sh"
# shellcheck source=/dev/null
source "$REPO_D/hostlib/script-kb.sh"
# shellcheck source=/dev/null
source "$REPO_D/hostlib/script-vga.sh"
# shellcheck source=/dev/null
source "$REPO_D/hostlib/script.sh"
# shellcheck source=/dev/null
source "$REPO_D/hostlib/script-serial.sh"
# shellcheck source=/dev/null
source "$REPO_D/hostlib/script-fdisk.sh"
# shellcheck source=/dev/null
source "$REPO_D/hostlib/slackware.sh"
# shellcheck source=/dev/null
source "$REPO_D/hostlib/extract.sh"
# shellcheck source=/dev/null
source "$REPO_D/slackware/sysinstall.sh"

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

# --- command_quote_posix_word -----------------------------------------
assert_eq "quote/plain" "plain" "$(command_quote_posix_word plain)"
assert_eq "quote/comma-eq" "if=ide,index=0" "$(command_quote_posix_word 'if=ide,index=0')"
assert_eq "quote/space" "'a b'" "$(command_quote_posix_word 'a b')"
assert_eq "quote/empty" "''" "$(command_quote_posix_word '')"
assert_eq "quote/single-quote" "'a'\\''b'" "$(command_quote_posix_word "a'b")"
assert_eq "quote/amp" "'a&b'" "$(command_quote_posix_word 'a&b')"

# --- QEMU networking --------------------------------------------------------
for value in 0 false FALSE False no NO No off OFF Off disabled DISABLED n F null NIL; do
    QEMU_NET_ENABLED=$value
    assert_fail "qemu/net-disabled-$value" network_is_enabled
done
QEMU_NET_ENABLED=true
assert_ok "qemu/net-enabled-true" network_is_enabled
QEMU_NET_ENABLED=1
assert_ok "qemu/net-enabled-1" network_is_enabled
unset QEMU_NET_ENABLED
config_set_defaults
assert_eq "qemu/net-default" "true" "$QEMU_NET_ENABLED"
QEMU_NET_FORWARD="2200:22,2323:23 8080:80"
assert_eq "qemu/net-forward-custom" ",hostfwd=tcp:127.0.0.1:2200-:22,hostfwd=tcp:127.0.0.1:2323-:23,hostfwd=tcp:127.0.0.1:8080-:80" "$(network_render_forward_suffix)"
QEMU_NET_FORWARD=none
assert_eq "qemu/net-forward-none" "" "$(network_render_forward_suffix)"
QEMU_NET_FORWARD=invalid
assert_fail "qemu/net-forward-invalid" network_render_forward_suffix
QEMU_NET_FORWARD="8080:80 2323:23 2200:22 8443:443"
assert_eq "qemu/net-forward-display" $'    SSH:     localhost:2200 -> guest :22\n    Telnet:  localhost:2323 -> guest :23\n    TCP:     localhost:8080 -> guest :80\n    TCP:     localhost:8443 -> guest :443' "$(network_print_forwards)"
QEMU_NET_FORWARD=none
assert_eq "qemu/net-forward-section-none" "" "$(network_print_endpoints | sed -n '/📡 Guest ports:/p')"
# shellcheck disable=SC2034 # Read by network_build in subsequent tests.
QEMU_NET_FORWARD=

# --- QMP-backed script command helpers --------------------------------------
assert_eq "qmp/hmp-batch-responses" $'response: first\nresponse: second' "$(
    # shellcheck disable=SC2329 # Invoked indirectly by qmp_hmp_commands.
    qmp_execute_hmp() {
        QMP_HMP_RESPONSE="response: $1"
    }
    qmp_hmp_commands first second
)"
assert_fail "qmp/hmp-requires-command" qmp_hmp_commands >/dev/null 2>&1
assert_fail "qmp/init-stops-after-prereq-failure" bash -c '
    source "$1/hostlib/qmp.sh"
    log_info() { :; }
    qmp_set_defaults() { :; }
    qmp_check_prereqs() { return 1; }
    qmp_negotiate_capabilities() { printf reached; return 0; }
    qmp_init
' _ "$REPO_D"
assert_fail "qemu/run-stops-after-prepare-failure" bash -c '
    source "$1/hostlib/qemu.sh"
    log_debug() { :; }
    qemu_prepare() { return 1; }
    COMMAND=boot
    qemu_run
' _ "$REPO_D"
qmp_log_tmp=$(mktemp -d)
QMP_LOG=$qmp_log_tmp/qmp.log
printf 'stale\n' >"$QMP_LOG"
qmp_log_reset
assert_eq "qmp/log-reset" "" "$(cat "$QMP_LOG")"
(
    exec 6>"$qmp_log_tmp/request"
    qmp_write_request '{"execute":"test","id":"test-id"}'
    printf '%s\n' '{"return":{},"id":"test-id"}' >"$qmp_log_tmp/response"
    exec 7<"$qmp_log_tmp/response"
    QMP_TIMEOUT=1
    qmp_read_response test-id
)
assert_eq "qmp/log-request-write" '{"execute":"test","id":"test-id"}' "$(cat "$qmp_log_tmp/request")"
assert_eq "qmp/log-transactions" '{"execute":"test","id":"test-id"}
{"return":{},"id":"test-id"}' "$(cat "$QMP_LOG")"
rm -rf "$qmp_log_tmp"
unset QMP_LOG
assert_eq "kb/type-string" $'shift-a\nb\nc\nd\ne' "$(
    qmp_hmp_commands() { printf '%s\n' "${1#sendkey }" >&2; }
    kb_type Abcde 2>&1
)"
assert_eq "kb/type-return" $'⌨️  ab ↩️\na\nb\nret' "$(
    qmp_hmp_commands() { printf '%s\n' "${1#sendkey }" >&2; }
    kb_type -n ab 2>&1
)"
assert_eq "kb/type-empty-return" $'⌨️   ↩️\nret' "$(
    qmp_hmp_commands() { printf '%s\n' "${1#sendkey }" >&2; }
    kb_type -n "" 2>&1
)"
assert_eq "kb/stdin-lines" $'one<RET>\n<RET>\ntwo' "$(
    kb_type() {
        local typed
        if [ "${1:-}" = -n ]; then
            shift
            typed="$1<RET>"
        else
            typed=$1
        fi
        printf '%s\n' "$typed" >&2
    }
    printf 'one\n\ntwo' | kb_type_stdin 2>&1
)"
assert_eq "kb/multiple-key-press" $'👇 down down spc\ndown\ndown\nspc' "$(
    qmp_hmp_commands() { printf '%s\n' "${1#sendkey }"; }
    kb_press down down spc
)"
assert_eq "kb/repeated-key-press" $'👇 down (5 times)\ndown\ndown\ndown\ndown\ndown' "$(
    qmp_hmp_commands() { printf '%s\n' "${1#sendkey }" >&2; }
    kb_repeat down 5 2>&1
)"
assert_fail "kb/repeat-missing-key" kb_repeat >/dev/null 2>&1
assert_fail "kb/repeat-extra-argument" kb_repeat down 2 extra >/dev/null 2>&1
assert_eq "script/change-image-default" "change floppy0 boot.img raw" "$(
    # shellcheck disable=SC2329 # Invoked indirectly by script_change_image.
    qmp_hmp_commands() { printf '%s\n' "$1"; }
    script_change_image boot.img
)"
assert_eq "script/change-image-format" "change floppy0 boot.img raw" "$(
    # shellcheck disable=SC2329 # Invoked indirectly by script_change_image.
    qmp_hmp_commands() { printf '%s\n' "$1"; }
    script_change_image boot.img floppy0 raw
)"

# --- download_path_is_safe_relative -----------------------------------------
assert_ok   "safe/sub"        download_path_is_safe_relative "a/b.tgz"
assert_ok   "safe/single"     download_path_is_safe_relative "file.iso"
assert_fail "safe/abs"        download_path_is_safe_relative "/etc/passwd"
assert_fail "safe/dotdot"     download_path_is_safe_relative "../x"
assert_fail "safe/mid-dotdot" download_path_is_safe_relative "a/../b"
assert_fail "safe/empty"      download_path_is_safe_relative ""
assert_fail "safe/bare-dotdot" download_path_is_safe_relative ".."

download_tmp=$(mktemp -d)
printf 'nested/file.img https://example.invalid/file.img' >"$download_tmp/manifest"
assert_ok "download/manifest-nested-path" bash -c '
    source "$1/hostlib/logging.sh"
    source "$1/hostlib/download.sh"
    wget() { printf downloaded >"$4"; }
    download_manifest "$2/manifest" "$2/output"
' _ "$REPO_D" "$download_tmp"
assert_eq "download/manifest-nested-file" "downloaded" "$(cat "$download_tmp/output/nested/file.img")"
assert_fail "download/manifest-propagates-wget-failure" bash -c '
    source "$1/hostlib/logging.sh"
    source "$1/hostlib/download.sh"
    wget() { return 1; }
    download_manifest "$2/manifest" "$2/failed"
' _ "$REPO_D" "$download_tmp"
rm -rf "$download_tmp"

# --- download_url_path_depth ------------------------------------------------
assert_eq "depth/one"   "1" "$(download_url_path_depth 'http://example.com/a')"
assert_eq "depth/three" "3" "$(download_url_path_depth 'http://example.com/a/b/c')"
assert_eq "depth/trailing" "2" "$(download_url_path_depth 'http://example.com/a/b/')"
assert_eq "depth/mirror" "2" "$(download_url_path_depth 'http://mirrors.slackware.com/slackware/slackware-3.6/')"

# --- config_find_file --------------------------------------------------
tmp=$(mktemp -d)
mkdir -p "$tmp/parent/child"
: >"$tmp/parent/shared.txt"
: >"$tmp/parent/child/local.txt"
assert_eq "config/local"  "$tmp/parent/child/local.txt"  "$(config_find_file "$tmp/parent/child" local.txt)"
assert_eq "config/parent" "$tmp/parent/shared.txt"        "$(config_find_file "$tmp/parent/child" shared.txt)"
assert_fail "config/missing" config_find_file "$tmp/parent/child" missing.txt
rm -rf "$tmp"

# --- retro command parsing --------------------------------------------------
assert_fail "retro/requires-command" "$REPO_D/retro" >/dev/null 2>&1
assert_eq "retro/help-usage" "Usage: retro COMMAND [CONFIG]" \
    "$("$REPO_D/retro" help | sed -n '/^Usage:/p')"
assert_fail "retro/rejects-unknown-command" "$REPO_D/retro" not-a-command >/dev/null 2>&1
assert_fail "retro/rejects-extra-arguments" "$REPO_D/retro" help . extra >/dev/null 2>&1

# --- script_import ----------------------------------------------------------
imp_tmp=$(mktemp -d)
mkdir -p "$imp_tmp/distro/1.0"
printf 'imported_ok() { echo yes; }\n' >"$imp_tmp/distro/helper.sh"
printf 'broken() {\n}\n' >"$imp_tmp/distro/broken.sh"

# A good helper is sourced relative to the install script's directory.
assert_eq "import/good-helper" "yes" "$(
    QEMU_INSTALL_SCRIPT="$imp_tmp/distro/1.0/install.sh"
    script_import ../helper.sh
    imported_ok
)"

# A syntax error aborts the install subshell before any later commands run.
assert_eq "import/broken-aborts" "" "$(
    QEMU_INSTALL_SCRIPT="$imp_tmp/distro/1.0/install.sh"
    script_import ../broken.sh 2>/dev/null
    echo "not reached"
)"

# Runs script_import for a broken helper in a subshell to observe its status.
# shellcheck disable=SC2329 # Invoked indirectly by assert_fail.
import_broken_status() {
    (
        # shellcheck disable=SC2030,SC2034 # Read by script_import.
        QEMU_INSTALL_SCRIPT="$imp_tmp/distro/1.0/install.sh"
        script_import ../broken.sh 2>/dev/null
    )
}
assert_fail "import/broken-status" import_broken_status

# Runs script_import for a missing helper in a subshell to observe its status.
# shellcheck disable=SC2329 # Invoked indirectly by assert_fail.
import_missing_status() {
    (
        # shellcheck disable=SC2030,SC2034 # Read by script_import.
        QEMU_INSTALL_SCRIPT="$imp_tmp/distro/1.0/install.sh"
        script_import ../missing.sh 2>/dev/null
    )
}
assert_fail "import/missing-status" import_missing_status
rm -rf "$imp_tmp"

# --- command_render_sh / _cmd ------------------------------------------
# shellcheck disable=SC2034  # Read by the render functions via the global.
QEMU_ARGS=(qemu-system-i386 -drive "if=ide,index=0,format=qcow2,file=hda.img" "weird arg" "amp&x" "pct%v" "par(s)")
assert_eq "render/sh" \
    "qemu-system-i386 -drive if=ide,index=0,format=qcow2,file=hda.img 'weird arg' 'amp&x' pct%v 'par(s)'" \
    "$(command_render_sh)"
assert_eq "render/cmd" \
    'qemu-system-i386 -drive if=ide,index=0,format=qcow2,file=hda.img "weird arg" "amp&x" pct%%v "par(s)"' \
    "$(command_render_cmd)"

# Option-specific settings contain only values; raw argument groups are arrays.
assert_eq "command/value-options-and-arrays" $'qemu-system-i386
-machine
pc
-smp
1
-m
64M
-display
cocoa
-accel
tcg
-vga
cirrus
-netdev
user,id=internet
-boot
order=c
-name
two words' "$(
    set +u
    QEMU_SYSTEM=qemu-system-i386
    QEMU_MACHINE=pc
    QEMU_SMP=1
    QEMU_RAM=64M
    QEMU_QMP_PIPE=none
    QEMU_MONITOR_PORT=none
    QEMU_SERIALS=()
    QEMU_PARALLELS=()
    QEMU_DISPLAY=cocoa
    QEMU_ACCEL=tcg
    QEMU_VGA=cirrus
    QEMU_NETWORK=(-netdev user,id=internet)
    QEMU_GLOBALS=()
    QEMU_DRIVES=()
    QEMU_BOOT_ORDER=order=c
    QEMU_EXTRA=(-name "two words")
    command_build
    printf '%s\n' "${QEMU_ARGS[@]}"
)"

# --- QEMU display scaling ---------------------------------------------------
qemu_mock_tmp=$(mktemp -d)
qemu_mock="$qemu_mock_tmp/qemu-system-i386"
# shellcheck disable=SC2016 # The mock reads QEMU_MOCK_VERSION at execution time.
printf '#!/usr/bin/env bash\nprintf "QEMU emulator version %%s\\n" "$QEMU_MOCK_VERSION"\n' >"$qemu_mock"
chmod +x "$qemu_mock"
# shellcheck disable=SC2034 # Read by config_detect_qemu_major through QEMU_SYSTEM.
QEMU_SYSTEM=$qemu_mock

export QEMU_MOCK_VERSION=11.0.0
QEMU_DISPLAY="cocoa"
config_apply_display_scaling
assert_eq "display/cocoa-qemu11" "cocoa,zoom-to-fit=on,zoom-interpolation=on" "$QEMU_DISPLAY"

export QEMU_MOCK_VERSION=10.1.0
QEMU_DISPLAY="cocoa"
config_apply_display_scaling
assert_eq "display/cocoa-qemu10" "cocoa" "$QEMU_DISPLAY"

export QEMU_MOCK_VERSION=11.0.0
QEMU_DISPLAY="gtk"
config_apply_display_scaling
assert_eq "display/gtk-qemu11" "gtk" "$QEMU_DISPLAY"

rm -rf "$qemu_mock_tmp"

# --- fdisk prompt helpers ---------------------------------------------------
assert_eq "fdisk/range-first" "1 1015" "$(fdisk_parse_range "First cylinder (1-1015):   ")"
assert_eq "fdisk/range-last" "131 1015" "$(fdisk_parse_range "Last cylinder or +size or +sizeM or +sizeK (131-1015): ")"
assert_eq "fdisk/range-default" "131 1015" "$(fdisk_parse_range "First cylinder (131-1015, default 131): ")"
assert_eq "fdisk/range-bracketed" "1 520" "$(fdisk_parse_range "Last cylinder or +size or +sizeM or +sizeK ([1]-520): ")"
assert_fail "fdisk/range-answered" fdisk_parse_range "First cylinder (1-1015): 1"
assert_fail "fdisk/range-missing" fdisk_parse_range "no fdisk prompt here"

# --- Slackware sysinstall driver --------------------------------------------
sysinstall_tmp=$(mktemp -d)
mkdir -p "$sysinstall_tmp/fat/install"
assert_eq "sysinstall/type-base" "1" "$(cd "$sysinstall_tmp" && slackware_sysinstall_type)"
mkdir -p "$sysinstall_tmp/fat/install/x1"
assert_eq "sysinstall/type-x" "2" "$(cd "$sysinstall_tmp" && slackware_sysinstall_type)"
mkdir -p "$sysinstall_tmp/fat/install/t1"
assert_eq "sysinstall/type-tex" "3" "$(cd "$sysinstall_tmp" && slackware_sysinstall_type)"
rm -rf "$sysinstall_tmp"

assert_ok "sysinstall/modem-1.01" text_contains_regex \
    "Do you have a modem (y/n)? " "$SLACKWARE_SYSINSTALL_MODEM_PROMPT"
assert_ok "sysinstall/modem-beta" text_contains_regex \
    "do you have a modem (y/n)? " "$SLACKWARE_SYSINSTALL_MODEM_PROMPT"
assert_ok "sysinstall/mouse-1.01" text_contains_regex \
    "Do you have a mouse (y/n)? " "$SLACKWARE_SYSINSTALL_MOUSE_PROMPT"
assert_ok "sysinstall/mouse-beta" text_contains_regex \
    "do you have a mouse (y/n)? " "$SLACKWARE_SYSINSTALL_MOUSE_PROMPT"
assert_ok "sysinstall/package-mode-beta" text_contains_regex \
    "Do you want to be prompted before packages are installed? (y/n): " \
    "$SLACKWARE_SYSINSTALL_PACKAGE_MODE_PROMPT"

# Boot-disk creation swaps in a fresh disposable 1.44 MB image.
sysinstall_tmp=$(mktemp -d)
assert_eq "sysinstall/bootdisk" "bootdisk.img:1474560" "$(
    cd "$sysinstall_tmp" || exit 1
    # shellcheck disable=SC2329 # Invoked indirectly by the boot-disk helper.
    script_change_floppy() {
        printf '%s:%s\n' "$1" "$(wc -c <"$1" | tr -d ' ')"
    }
    slackware_sysinstall_bootdisk
)"
rm -rf "$sysinstall_tmp"

# Package questions can repeat any number of times, with an optional boot-disk
# acknowledgement before syssetup's modem question terminates the loop.
assert_eq "sysinstall/package-loop" "<y>
<y>
<bootdisk>
<>
<n>" "$(
    sysinstall_statuses=(0 0 1 2)
    sysinstall_i=0
    # shellcheck disable=SC2329 # Invoked indirectly by the package driver.
    serial_wait_alternative() {
        local status=${sysinstall_statuses[$sysinstall_i]}
        sysinstall_i=$((sysinstall_i + 1))
        return "$status"
    }
    # shellcheck disable=SC2329 # Invoked indirectly by the package driver.
    serial_send() { printf '<%s>\n' "$1"; }
    # shellcheck disable=SC2329 # Invoked indirectly by the package driver.
    slackware_sysinstall_bootdisk() { printf '<bootdisk>\n'; }
    slackware_sysinstall_packages
)"

# 1.0beta offers a global prompt mode; declining installs all selected packages
# without individual questions before continuing to boot disk creation.
assert_eq "sysinstall/package-loop-beta" "<n>
<bootdisk>
<>
<n>" "$(
    sysinstall_statuses=(3 1 2)
    sysinstall_i=0
    # shellcheck disable=SC2329 # Invoked indirectly by the package driver.
    serial_wait_alternative() {
        local status=${sysinstall_statuses[$sysinstall_i]}
        sysinstall_i=$((sysinstall_i + 1))
        return "$status"
    }
    # shellcheck disable=SC2329 # Invoked indirectly by the package driver.
    serial_send() { printf '<%s>\n' "$1"; }
    # shellcheck disable=SC2329 # Invoked indirectly by the package driver.
    slackware_sysinstall_bootdisk() { printf '<bootdisk>\n'; }
    slackware_sysinstall_packages
)"

# --- Guest logging and configuration helpers -------------------------------
guest_log_tmp=$(mktemp)
(
    # shellcheck disable=SC2034 # Read by the sourced guest logger.
    POSTINST_LOG=$guest_log_tmp
    # shellcheck disable=SC2034 # Read by the sourced guest logger.
    POSTINST_DEBUG=0
    # shellcheck source=/dev/null
    source "$REPO_D/guestlib/logging.sh"
    log INFO "plain message" >/dev/null 2>&1
    log WARN "warning message" >/dev/null 2>&1
    log DEBUG "hidden message" >/dev/null 2>&1
    # shellcheck disable=SC2034 # Read by the sourced guest logger.
    POSTINST_DEBUG=1
    log DEBUG "visible message" >/dev/null 2>&1
)
assert_eq "guest-log/levels" $'plain message\nWARN: warning message\nDEBUG: visible message' \
    "$(cat "$guest_log_tmp")"
rm -f "$guest_log_tmp"

# The helpers are sourced directly below, without the guest runner.
# shellcheck disable=SC2329 # Invoked indirectly by sourced guest helpers.
log() { :; }

# --- Early Slackware configuration helpers ---------------------------------
config_tmp=$(mktemp -d)
mkdir -p "$config_tmp/etc/rc.d"
printf '# original rc.modules\n' >"$config_tmp/etc/rc.d/rc.modules"
(
    ETC_D="$config_tmp/etc"
    # shellcheck disable=SC2034 # Read by the sourced guest helper.
    MOD_ENABLE='ne  io=0x300 debug=1
8390'
    # shellcheck source=/dev/null
    source "$REPO_D/guestlib/config/modules.sh" >/dev/null
    _mod_config >/dev/null
)
assert_eq "modules/backup" "# original rc.modules" \
    "$(cat "$config_tmp/etc/rc.d/rc.modules~")"
assert_eq "modules/slackware-direct" "# original rc.modules
/sbin/modprobe ne io=0x300 debug=1
/sbin/modprobe 8390" \
    "$(cat "$config_tmp/etc/rc.d/rc.modules")"
rm -rf "$config_tmp"

config_tmp=$(mktemp -d)
mkdir -p "$config_tmp/etc"
printf '#s1:12345:respawn:/sbin/agetty 9600 ttyS1\n' >"$config_tmp/etc/inittab"
printf 'CONSOLE /dev/console\nENV_SUPATH value\n' >"$config_tmp/etc/login.defs"
printf 'console\n' >"$config_tmp/etc/securetty"
(
    ETC_D="$config_tmp/etc"
    # shellcheck disable=SC2034 # Read by the sourced guest helper.
    TTY_DEV=ttyS0
    # shellcheck disable=SC2034 # Read by the sourced guest helper.
    TTY_ID=s0
    # shellcheck disable=SC2034 # Read by the sourced guest helper.
    TTY_RUNLEVELS=123456
    # shellcheck source=/dev/null
    source "$REPO_D/guestlib/config/tty.sh" >/dev/null
    _tty_config >/dev/null
    # shellcheck source=/dev/null
    source "$REPO_D/guestlib/config/tty.sh" >/dev/null
    _tty_config >/dev/null
)
assert_eq "tty/inittab-backup" \
    "#s1:12345:respawn:/sbin/agetty 9600 ttyS1" \
    "$(cat "$config_tmp/etc/inittab.orig")"
assert_eq "tty/getty-count" "1" \
    "$(grep -c '^s0:123456:respawn:/sbin/agetty 9600 ttyS0$' "$config_tmp/etc/inittab")"
assert_eq "tty/login-defs" "#CONSOLE /dev/console
ENV_SUPATH value" "$(cat "$config_tmp/etc/login.defs")"
assert_eq "tty/login-defs-backup" "CONSOLE /dev/console
ENV_SUPATH value" "$(cat "$config_tmp/etc/login.defs.orig")"
assert_eq "tty/securetty" "console
ttyS0" "$(cat "$config_tmp/etc/securetty")"
assert_eq "tty/securetty-backup" "console" \
    "$(cat "$config_tmp/etc/securetty.orig")"
rm -rf "$config_tmp"

config_tmp=$(mktemp -d)
mkdir -p "$config_tmp/etc/rc.d"
printf '# original rc.inet1\n' >"$config_tmp/etc/rc.d/rc.inet1"
printf 'oldhost\n' >"$config_tmp/etc/HOSTNAME"
(
    ETC_D="$config_tmp/etc"
    NET_HOSTNAME=darkstar
    NET_IPADDR=10.0.2.15
    NET_NETMASK=255.255.255.0
    NET_NETWORK=10.0.2.0
    NET_BROADCAST=10.0.2.255
    NET_GATEWAY=10.0.2.2
    NET_NAMESERVER=10.0.2.3
    NET_DOMAINNAME=retro.net
    # shellcheck disable=SC2034 # Read by the sourced guest helper.
    NET_ANCIENT_ROUTE=1
    # shellcheck disable=SC2034 # Read by the sourced guest helper.
    NET_ROUTE_PATH=/etc/route
    NET_GATEWAY_HWADDR=
    NET_NAMESERVER_HWADDR=
    NET_IFCONFIG_PATH=
    NET_ARP_PATH=
    NET_HOSTNAME_INIT_SET=
    # shellcheck source=/dev/null
    source "$REPO_D/guestlib/config/net.sh" >/dev/null
    set +u
    _net_config >/dev/null
    set -u
)
assert_eq "net/1.01-hostname" "darkstar" "$(cat "$config_tmp/etc/HOSTNAME")"
assert_eq "net/1.01-backup" "# original rc.inet1" \
    "$(cat "$config_tmp/etc/rc.d/rc.inet1~")"
# shellcheck disable=SC2016 # Match the literal variable in generated rc.inet1.
assert_ok "net/1.01-route" grep -q '^/etc/route -n add \$NETWORK$' \
    "$config_tmp/etc/rc.d/rc.inet1"
assert_eq "net/1.01-resolver" "# domain retro.net
# search retro.net
nameserver 10.0.2.3" "$(cat "$config_tmp/etc/resolv.conf")"
rm -rf "$config_tmp"

config_tmp=$(mktemp -d)
mkdir -p "$config_tmp/etc"
printf '# stock rc.net\n' >"$config_tmp/etc/rc.net"
printf '1.2.3.4\tdarkstar\n1.2.3.0\tnetwork\n1.2.3.1\trouter\n127.0.0.1\tlocalhost\n' \
    >"$config_tmp/etc/hosts"
# shellcheck disable=SC2034 # Assignments are read by the sourced guest helper.
(
    ETC_D="$config_tmp/etc"
    NET_HOSTNAME=darkstar
    NET_IPADDR=10.0.2.15
    NET_NETMASK=255.255.255.0
    NET_NETWORK=10.0.2.0
    NET_BROADCAST=10.0.2.255
    NET_GATEWAY=10.0.2.2
    NET_NAMESERVER=10.0.2.3
    NET_DOMAINNAME=retro.net
    NET_GATEWAY_HWADDR=
    NET_NAMESERVER_HWADDR=
    NET_IFCONFIG_PATH=
    NET_ROUTE_PATH=
    NET_ARP_PATH=
    NET_HOSTNAME_INIT_SET=
    NET_INIT_SCRIPT_PATH=
    NET_RC_NET_PATH=
    # shellcheck source=/dev/null
    source "$REPO_D/guestlib/config/net.sh" >/dev/null
    set +u
    _net_config >/dev/null
    set -u
)
assert_eq "net/beta-host" "darkstar" "$(cat "$config_tmp/etc/host")"
assert_eq "net/beta-domain" "retro.net" "$(cat "$config_tmp/etc/domain")"
assert_eq "net/beta-hosts" $'10.0.2.15\tdarkstar\n10.0.2.0\tnetwork\n10.0.2.2\trouter\n127.0.0.1\tlocalhost' \
    "$(cat "$config_tmp/etc/hosts")"
assert_eq "net/beta-preserves-rc.net" "# stock rc.net" \
    "$(cat "$config_tmp/etc/rc.net")"
rm -rf "$config_tmp"

wait_screen="ready"
# shellcheck disable=SC2329 # Invoked indirectly by vga_wait.
qmp_vm_is_running() { return 0; }
# shellcheck disable=SC2329 # Invoked indirectly by vga_wait.
vga_read_text() { printf '%s\n' "$wait_screen"; }
# shellcheck disable=SC2329 # Invoked indirectly by kb_type.
kb_type() { return 0; }
# shellcheck disable=SC2329 # Invoked indirectly by kb_type.
qmp_hmp_commands() { return 0; }
wait_output=$(vga_wait "ready")
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
vga_wait -l "first line" "second line" >"$wait_output_tmp"
wait_status=$?
wait_output=$(cat "$wait_output_tmp")
rm -f "$wait_output_tmp"
assert_eq "script/wait-line-sequence-status" "0" "$wait_status"
assert_eq "script/wait-line-sequence-output" \
    "⏳ first line🖥️  first line[K
⏳ second line🖥️  second line[K" \
    "$wait_output"

# --- screen regex matcher ----------------------------------------------------
# The installed-system shell prompt is "\h\$", so it is a bare "#" before the
# hostname is set and "HOST#" afterwards. Anchors apply per line, and screen
# lines are padded with trailing spaces.
shell_prompt='^[^[:space:]]*# *$'
assert_ok "script/contains-regex-bare-prompt" text_contains_regex "#   " "$shell_prompt"
assert_ok "script/contains-regex-host-prompt" text_contains_regex "rex#" "$shell_prompt"
assert_fail "script/contains-regex-prose" text_contains_regex "Press # to continue" "$shell_prompt"

wait_screen="Have fun!
rex#"
vga_wait -r "$shell_prompt" >/dev/null
assert_eq "script/wait-regex-status" "0" "$?"

wait_screen="no prompt here"
vga_wait -t 0.1 -r "$shell_prompt" >/dev/null
assert_eq "script/wait-regex-timeout" "1" "$?"

# --- serial regex matcher ----------------------------------------------------
# Patterns are extended regexes (grep -E), so escaped parens match literally,
# matching the style used by dialog_answer -r callers.
regex_screen="Slackware Linux Setup (version 3.4)"
assert_ok "serial/contains-regex" text_contains_regex "$regex_screen" "Setup \(version .*\)"
assert_fail "serial/contains-regex-miss" text_contains_regex "$regex_screen" "Setup \(build .*\)"

# --- dialog helpers ----------------------------------------------------------
# Dialog screens are seeded up front and answered through serial_send.
# shellcheck source=/dev/null
source "$REPO_D/hostlib/script-dialog.sh"

case_tmp=$(mktemp -d)
SERIAL_LOG=$case_tmp/log
# shellcheck disable=SC2329 # Invoked indirectly by dialog helpers.
serial_send() { printf '%s\n' "$1" >>"$case_tmp/answers"; }
exec 4>&2 2>/dev/null

# Screens are answered in stream order; unmatched alternatives stay unanswered.
SERIAL_MATCH_OFFSET=0
: >"$case_tmp/answers"
printf '%s\n' \
    'TITLE: SECOND' 'RESPONSE: ' \
    'TITLE: FIRST' 'RESPONSE: ' \
    'TITLE: DONE' 'RESPONSE: ' \
    >"$SERIAL_LOG"
# shellcheck disable=SC2329 # Invoked indirectly by dialog_answer.
case_echo_title() { dialog_answer any "$1" "$1"; }
dialog_answer \
    -x any "FIRST" -f case_echo_title \
    any "SECOND" -f case_echo_title \
    any "NEVER ASKED" -f case_echo_title >/dev/null
wait_status=$?
assert_eq "dialog/case-status" "0" "$wait_status"
assert_eq "dialog/case-out-of-order" "SECOND
FIRST" "$(cat "$case_tmp/answers")"

# dialog_answer directly answers matching TYPE TITLE ANSWER triples.
SERIAL_MATCH_OFFSET=0
: >"$case_tmp/answers"
dialog_answer -x any "FIRST" "one" any "SECOND" "two" >/dev/null
wait_status=$?
assert_eq "dialog/answer-status" "0" "$wait_status"
assert_eq "dialog/answer-out-of-order" "two
one" "$(cat "$case_tmp/answers")"

# dialog_answer -x answers the marked triple and then returns.
SERIAL_MATCH_OFFSET=0
: >"$case_tmp/answers"
printf '%s\n' \
    'TITLE: FIRST' 'RESPONSE: ' \
    'TITLE: DONE' 'RESPONSE: ' \
    'TITLE: SECOND' 'RESPONSE: ' \
    >"$SERIAL_LOG"
dialog_answer any "FIRST" "one" -x any "DONE" "done" any "SECOND" "two" >/dev/null
wait_status=$?
assert_eq "dialog/answer-terminal-status" "0" "$wait_status"
assert_eq "dialog/answer-terminal" "one
done" "$(cat "$case_tmp/answers")"

# dialog_answer handles repeated type/title alternatives in listed order.
SERIAL_MATCH_OFFSET=0
: >"$case_tmp/answers"
printf '%s\n' \
    'TITLE: CHOOSE PARTITION' 'TYPE: inputbox' 'RESPONSE: ' \
    'TITLE: CHOOSE PARTITION' 'TYPE: inputbox' 'RESPONSE: ' \
    'TITLE: NEVER' 'TYPE: inputbox' 'RESPONSE: ' \
    >"$SERIAL_LOG"
dialog_answer \
    inputbox "CHOOSE PARTITION" "/dev/hdb1" \
    -x inputbox "CHOOSE PARTITION" q \
    inputbox "NEVER" "unused" >/dev/null
wait_status=$?
assert_eq "dialog/answer-repeat-terminal-status" "0" "$wait_status"
assert_eq "dialog/answer-repeat-terminal" "/dev/hdb1
q" "$(cat "$case_tmp/answers")"

# dialog_answer treats msgbox and textbox as interchangeable.
SERIAL_MATCH_OFFSET=0
: >"$case_tmp/answers"
printf '%s\n' \
    'TITLE: SWAP SPACE CONFIGURED' 'TYPE: textbox' 'RESPONSE: ' \
    'TITLE: DONE' 'TYPE: msgbox' 'RESPONSE: ' \
    >"$SERIAL_LOG"
dialog_answer \
    -x msgbox "SWAP SPACE CONFIGURED" ok \
    msgbox "DONE" unused >/dev/null
wait_status=$?
assert_eq "dialog/answer-textbox-status" "0" "$wait_status"
assert_eq "dialog/answer-textbox" "ok" "$(cat "$case_tmp/answers")"

# A repeated title is handled once per occurrence, in the order listed.
SERIAL_MATCH_OFFSET=0
: >"$case_tmp/answers"
printf '%s\n' \
    'TITLE: REPEAT' 'RESPONSE: ' \
    'TITLE: REPEAT' 'RESPONSE: ' \
    'TITLE: DONE' 'RESPONSE: ' \
    >"$SERIAL_LOG"
# shellcheck disable=SC2329 # Invoked indirectly by dialog_answer.
case_answer_one() { dialog_answer any "$1" "one"; }
# shellcheck disable=SC2329 # Invoked indirectly by dialog_answer.
case_answer_two() { dialog_answer any "$1" "two"; }
dialog_answer any "REPEAT" -f case_answer_one -x any "REPEAT" -f case_answer_two >/dev/null
assert_eq "dialog/case-repeat" "one
two" "$(cat "$case_tmp/answers")"

# dialog_answer can distinguish screens that share a title but have different types.
SERIAL_MATCH_OFFSET=0
: >"$case_tmp/answers"
printf '%s\n' \
    'TITLE: MODEM CONFIGURATION' 'TYPE: menu' 'RESPONSE: ' \
    'TITLE: DONE' 'TYPE: msgbox' 'RESPONSE: ' \
    >"$SERIAL_LOG"
# shellcheck disable=SC2329 # Invoked indirectly by dialog_answer.
case_answer_yesno() { dialog_answer yesno "$1" "no"; }
# shellcheck disable=SC2329 # Invoked indirectly by dialog_answer.
case_answer_menu() { dialog_answer menu "$1" "no modem"; }
dialog_answer \
    yesno "MODEM CONFIGURATION" -f case_answer_yesno \
    -x menu "MODEM CONFIGURATION" -f case_answer_menu >/dev/null
assert_eq "dialog/case-type" "no modem" "$(cat "$case_tmp/answers")"

# dialog_answer -i dispatches same-title menus by required full item text.
SERIAL_MATCH_OFFSET=0
: >"$case_tmp/answers"
printf '%s\n' \
    'TITLE: Debian GNU/Linux Installation Main Menu' \
    'TYPE: menu' \
    'ITEM: Next :: Configure the Base System' \
    'ITEM: M :: Configure the Base System' \
    'ITEM: N :: Configure the Network' \
    'RESPONSE: ' \
    >"$SERIAL_LOG"
# shellcheck disable=SC2329 # Invoked indirectly by dialog_answer.
case_answer_next() { dialog_answer menu "$1" Next; }
dialog_answer \
    menu "Debian GNU/Linux Installation Main Menu" -i "Next :: Configure the Network" -f case_answer_next \
    -x menu "Debian GNU/Linux Installation Main Menu" -i "Next :: Configure the Base System" -f case_answer_next >/dev/null
assert_eq "dialog/case-item" "Next" "$(cat "$case_tmp/answers")"

# dialog_answer -i -r matches required full item text as an extended regex.
SERIAL_MATCH_OFFSET=0
: >"$case_tmp/answers"
printf '%s\n' \
    'TITLE: Debian GNU/Linux Installation Main Menu' \
    'TYPE: menu' \
    'ITEM: Next :: Initialize and Activate a Swap Partition' \
    'ITEM: C :: Initialize and Activate a Swap Partition' \
    'RESPONSE: ' \
    >"$SERIAL_LOG"
dialog_answer \
    -x menu "Debian GNU/Linux Installation Main Menu" -i -r "Next :: Initialize and Activate .*Swap" -f case_answer_next >/dev/null
assert_eq "dialog/case-item-regex" "Next" "$(cat "$case_tmp/answers")"

# dialog_answer -n matches without sending a response and takes no answer.
SERIAL_MATCH_OFFSET=0
: >"$case_tmp/answers"
SERIAL_MATCHED_TEXT=
printf '%s\n' \
    'TITLE: WAIT HERE' 'TYPE: menu' 'RESPONSE: ' \
    >"$SERIAL_LOG"
dialog_answer -x menu "WAIT HERE" -n >/dev/null
assert_eq "dialog/no-answer" "" "$(cat "$case_tmp/answers")"
assert_eq "dialog/no-answer-match" "TYPE: menu" "$SERIAL_MATCHED_TEXT"

# dialog_answer -x runs the marked handler and then returns.
SERIAL_MATCH_OFFSET=0
: >"$case_tmp/answers"
printf '%s\n' \
    'TITLE: FIRST' 'TYPE: msgbox' 'RESPONSE: ' \
    'TITLE: DONE' 'TYPE: msgbox' 'RESPONSE: ' \
    'TITLE: SECOND' 'TYPE: msgbox' 'RESPONSE: ' \
    >"$SERIAL_LOG"
dialog_answer \
    msgbox "FIRST" -f case_echo_title \
    -x msgbox "DONE" -f case_echo_title \
    msgbox "SECOND" -f case_echo_title >/dev/null
assert_eq "dialog/case-terminal" "FIRST
DONE" "$(cat "$case_tmp/answers")"

# dialog_answer matches -r keys as extended regexes.
SERIAL_MATCH_OFFSET=0
: >"$case_tmp/answers"
printf '%s\n' \
    'TITLE: FORMAT PARTITION /dev/hda2' 'TYPE: menu' 'RESPONSE: ' \
    'TITLE: DONE' 'TYPE: msgbox' 'RESPONSE: ' \
    >"$SERIAL_LOG"
dialog_answer \
    -x menu -r "FORMAT PARTITION( .*)?" Format \
    msgbox "DONE" unused >/dev/null
wait_status=$?
assert_eq "dialog/answer-regex-status" "0" "$wait_status"
assert_eq "dialog/answer-regex-key" "Format" "$(cat "$case_tmp/answers")"

# A single triple answers one screen directly, with -r regex title matching.
SERIAL_MATCH_OFFSET=0
: >"$case_tmp/answers"
printf '%s\n' \
    'TITLE: Slackware Linux Setup (version 3.4)' 'TYPE: menu' 'RESPONSE: ' \
    >"$SERIAL_LOG"
dialog_answer menu -r "Slackware Linux Setup \(version .*\)" ADDSWAP >/dev/null
assert_eq "dialog/answer-single-regex" "ADDSWAP" "$(cat "$case_tmp/answers")"

# dialog_answer -d selects the key for the item whose displayed text matches.
SERIAL_MATCH_OFFSET=0
: >"$case_tmp/answers"
printf '%s\n' \
    'TITLE: SOURCE MEDIA SELECTION' \
    'TYPE: menu' \
    'ITEM: 1 :: Install from a Slackware CD-ROM' \
    'ITEM: 2 :: Install from a hard drive partition' \
    'RESPONSE: ' \
    >"$SERIAL_LOG"
dialog_answer menu "SOURCE MEDIA SELECTION" -d "CD-ROM" >/dev/null
assert_eq "dialog/menu-text" "1" "$(cat "$case_tmp/answers")"

# dialog_answer -d -r matches item text as an extended regex.
SERIAL_MATCH_OFFSET=0
: >"$case_tmp/answers"
printf '%s\n' \
    'TITLE: Install from the Slackware CD-ROM' \
    'TYPE: menu' \
    'ITEM: 1 :: SCSI (/dev/scd0 or /dev/scd1)' \
    'ITEM: 7 :: Most IDE-interface CD drives' \
    'RESPONSE: ' \
    >"$SERIAL_LOG"
dialog_answer menu "Install from the Slackware CD-ROM" -d -r "IDE.*CD drives" >/dev/null
assert_eq "dialog/menu-text-regex" "7" "$(cat "$case_tmp/answers")"
exec 2>&4 4>&-
rm -rf "$case_tmp"

# --- serial transport --------------------------------------------------------
# Restore the real serial helpers after dialog tests mocked serial_send.
# shellcheck source=/dev/null
source "$REPO_D/hostlib/script-kb.sh"
# shellcheck source=/dev/null
source "$REPO_D/hostlib/script.sh"
# shellcheck source=/dev/null
source "$REPO_D/hostlib/script-serial.sh"
# shellcheck source=/dev/null
source "$REPO_D/hostlib/script-fdisk.sh"
# shellcheck source=/dev/null
source "$REPO_D/hostlib/script-dialog.sh"
serial_tmp=$(mktemp -d)
SERIAL_LOG=$serial_tmp/log
SERIAL_MATCH_OFFSET=0
SERIAL_TRANSCRIPT_OFFSET=0

sleep 0 &
SERIAL_DRAIN_PID=$!
assert_ok "serial/stop-reaps-drain" serial_stop
assert_eq "serial/stop-clears-pid" "" "$SERIAL_DRAIN_PID"

# Serial log offsets are zero-based bytes and preserve a partial final line.
printf 'alpha\nbeta' >"$SERIAL_LOG"
assert_eq "serial/read-offset-zero" $'alpha\nbeta' "$(serial_read_from_byte_offset 0)"
assert_eq "serial/read-offset-middle" "beta" "$(serial_read_from_byte_offset 6)"
assert_eq "serial/read-offset-eof" "" "$(serial_read_from_byte_offset 10)"
assert_eq "serial/read-offset-past-eof" "" "$(serial_read_from_byte_offset 20)"

# A transformed guest echo must not leave a stale queue head that prevents
# later exact echoes from being suppressed.
SERIAL_ECHO_LINES=("transformed outbound line" "d")
assert_ok "serial/echo-recovers-after-transformed-line" serial_consume_echo_if_match "d"
assert_eq "serial/echo-recovery-clears-stale-lines" "0" "${#SERIAL_ECHO_LINES[@]}"

# Transcript order: received text, matched waits, then transmitted text.
printf '%s\n' 'noise' 'MATCH' 'late' >"$SERIAL_LOG"
exec 9>"$serial_tmp/input"
serial_wait_match text_contains_line "MATCH" >/dev/null 2>"$serial_tmp/transcript"
serial_send "typed" 2>>"$serial_tmp/transcript"
printf '%s\n' 'typed' 'DONE' >>"$SERIAL_LOG"
serial_wait_match text_contains_line "DONE" >/dev/null 2>>"$serial_tmp/transcript"
assert_eq "serial/transcript" "➡️  noise
✅ MATCH
➡️  late
⬅️  typed
✅ DONE" "$(cat "$serial_tmp/transcript")"
assert_eq "serial/transcript-input" "typed" "$(cat "$serial_tmp/input")"
exec 9>&-

# serial_shell starts a screen-launched shell redirected to serial.
SERIAL_LOG=$serial_tmp/shell
SERIAL_MATCH_OFFSET=0
SERIAL_TRANSCRIPT_OFFSET=0
# shellcheck disable=SC2034 # Read by serial_shell_start.
SERIAL_SHELL_PROMPT="SERIAL#"
# shellcheck disable=SC2034 # Read by serial_shell_start.
SERIAL_SHELL_DEV=/dev/ttyS2
wait_screen="#"
qmp_strings=
# shellcheck disable=SC2329 # Invoked indirectly by serial_shell.
kb_type() {
    [ "${1:-}" != -n ] || shift
    qmp_strings="${qmp_strings}${qmp_strings:+
}$1"
}
# shellcheck disable=SC2329 # Invoked indirectly by serial_shell.
qmp_hmp_commands() { return 0; }
printf '%s\n' \
    'SERIAL# ' \
    'SERIAL# ' \
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
assert_eq "serial/shell-launcher" "[ -c /dev/ttyS2 ] || mknod /dev/ttyS2 c 4 67; PS1='SERIAL# ' sh -i </dev/ttyS2 >/dev/ttyS2 2>/dev/ttyS2" "$qmp_strings"
assert_eq "serial/shell-input" "echo -------------------------------------------------------------------------------- >/dev/console
echo 'Preparing scripted install...' >/dev/console
echo one
echo two >&2
exit" "$(cat "$serial_tmp/shell-input")"
exec 9>&-
unset SERIAL_SHELL_PROMPT SERIAL_SHELL_DEV

SERIAL_LOG=$serial_tmp/shell-nowait
SERIAL_MATCH_OFFSET=0
SERIAL_TRANSCRIPT_OFFSET=0
qmp_strings=
printf '%s\n' '# ' '# ' '# ' >"$SERIAL_LOG"
: >"$serial_tmp/shell-nowait-input"
exec 9>"$serial_tmp/shell-nowait-input"
serial_shell --no-wait "long-running install" >/dev/null 2>/dev/null
assert_eq "serial/shell-nowait-input" "echo -------------------------------------------------------------------------------- >/dev/console
echo 'Preparing scripted install...' >/dev/console
long-running install" "$(cat "$serial_tmp/shell-nowait-input")"
exec 9>&-

SERIAL_MATCH_OFFSET=0
SERIAL_TRANSCRIPT_OFFSET=0
exec 3>&2 2>/dev/null

# A prompt blocks without a trailing newline, so the partial line matches too.
printf 'TITLE: Foo\nRESPONSE: ' >"$SERIAL_LOG"
serial_wait_match text_contains_line "TITLE: Foo" >/dev/null
assert_eq "serial/title-consumed" "TITLE: Foo" "$SERIAL_MATCHED_TEXT"
serial_wait_match text_contains_line "RESPONSE:" >/dev/null
assert_eq "serial/partial-consumed" "RESPONSE: " "$SERIAL_MATCHED_TEXT"

# Consumed text never matches again; a fresh occurrence does.
assert_fail "serial/no-rematch" serial_scan_matches text_contains_line "TITLE: Foo"
printf '\nTITLE: Foo\n' >>"$SERIAL_LOG"
serial_wait_match text_contains_line "TITLE: Foo" >/dev/null
assert_eq "serial/second-occurrence" "TITLE: Foo" "$SERIAL_MATCHED_TEXT"

# Consuming a partial prompt must not hide later text on the same line.
SERIAL_LOG=$serial_tmp/appended-prompt
SERIAL_MATCH_OFFSET=0
# shellcheck disable=SC2034 # Read by serial_scan_matches.
SERIAL_TRANSCRIPT_OFFSET=0
printf 'Command (m for help): ' >"$SERIAL_LOG"
serial_wait_match text_contains_line "Command (m for help):" >/dev/null
printf 't\r\nPartition number (1-4): ' >>"$SERIAL_LOG"
serial_wait_match text_contains_line "Partition number (1-4):" >/dev/null
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
dialog_answer menu "Serial Screen" "picked" >/dev/null
assert_eq "serial/dialog-answer" "picked" "$(cat "$serial_tmp/answers")"

# dialog_answer must only peek before its handler re-waits for the title.
: >"$serial_tmp/answers"
printf '\nTITLE: Handled\nTYPE: menu\nRESPONSE: \nTITLE: Done\nRESPONSE: \n' >>"$SERIAL_LOG"
# shellcheck disable=SC2329 # Invoked indirectly by dialog_answer.
case_serial_answer() { dialog_answer menu "$1" "handled"; }
dialog_answer -x menu "Handled" -f case_serial_answer any "Done" unused >/dev/null
assert_eq "serial/case-handler" "handled" "$(cat "$serial_tmp/answers")"

# Echoed answers and CRLF output do not confuse serial matching.
printf 'picked\r\nTITLE: After Echo\r\n' >>"$SERIAL_LOG"
serial_wait_match text_contains_line "TITLE: After Echo" >/dev/null
assert_eq "serial/echo-crlf-consumed" "TITLE: After Echo" "$SERIAL_MATCHED_TEXT"

# fdisk_swap_root drives every fdisk prompt over the serial pipe; the shell
# prompt waits around it stay on the screen.
SERIAL_LOG=$serial_tmp/fdisk
# shellcheck disable=SC2034 # Read by fdisk_swap_root through serial helpers.
SERIAL_MATCH_OFFSET=0
: >"$serial_tmp/answers"
wait_screen="#"
printf '%s\n' \
    '# ' \
    '# ' \
    '# ' \
    '# ' \
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
fdisk_swap_root /dev/hda 64 >"$serial_tmp/fdisk-out" 2>"$serial_tmp/fdisk-err"
assert_eq "fdisk/serial-status" "0" "$?"
assert_eq "fdisk/serial-answers" "echo -------------------------------------------------------------------------------- >/dev/console
echo 'Preparing scripted install...' >/dev/console
echo -------------------------------------------------------------------------------- >/dev/console
echo 'Partitioning /dev/hda; this may take a while...' >/dev/console
[ -b /dev/hda ] || mknod /dev/hda b 3 0; fdisk /dev/hda
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

# The Red Hat C installer creates its missing disk node and partitions the
# disk through one fdisk_swap_root serial bootstrap.
redhat_partition_calls=$(
    # shellcheck source=/dev/null
    source "$REPO_D/redhat/c-install.sh"
    kb_press() { printf 'key %s\n' "$*"; }
    fdisk_swap_root() { printf 'fdisk-swap-root %s\n' "$*"; }
    partition_disk_helper
)
assert_eq "fdisk/redhat-single-serial-bootstrap" "key alt-f2
fdisk-swap-root /dev/hda 64
key alt-f1" "$redhat_partition_calls"

# --- dialog adapter serial routing -------------------------------------------
# The adapter sends screens and reads answers over SERIAL, and tees the
# transcript to the console for progress indication.
assert_fail "adapter/legacy-no-parameter-trimming" \
    grep -Eq '\$\{[^}]*[#%]' "$REPO_D/guestlib/dialog.sh"
mkfifo "$serial_tmp/port"
exec 8<>"$serial_tmp/port"
printf 'ok\n' >&8
SERIAL=$serial_tmp/port sh "$REPO_D/guestlib/dialog.sh" \
    --title Serial --msgbox hi 5 40 </dev/null >"$serial_tmp/console" 2>&1
assert_eq "adapter/serial-exit" "0" "$?"
IFS= read -r serial_line <&8 # divider
IFS= read -r serial_line <&8
assert_eq "adapter/serial-title" "TITLE: Serial" "$serial_line"
assert_ok "adapter/console-tee" grep -q "TITLE: Serial" "$serial_tmp/console"
exec 8<&-

# dialog.bak must not be used. Setup redirects dialog stderr into result files,
# so any real-dialog output there can corrupt responses.
cp "$REPO_D/guestlib/dialog.sh" "$serial_tmp/dialog"
printf '#!/bin/sh\necho "VIEW $*"\n' >"$serial_tmp/dialog.bak"
chmod +x "$serial_tmp/dialog" "$serial_tmp/dialog.bak"
mkfifo "$serial_tmp/port2"
exec 8<>"$serial_tmp/port2"
printf 'ok\n' >&8
SERIAL=$serial_tmp/port2 sh "$serial_tmp/dialog" \
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
SERIAL=$serial_tmp/port4 bash "$serial_tmp/dialog" \
    --title Path --inputbox "tag path" 10 40 \
    </dev/null >/dev/null 2>"$serial_tmp/inputbox-result"
assert_eq "adapter/inputbox-stderr-result" "/retro/tagfiles" "$(cat "$serial_tmp/inputbox-result")"
exec 8<&-

mkfifo "$serial_tmp/port7"
exec 8<>"$serial_tmp/port7"
printf 'PATH\n' >&8
SERIAL=$serial_tmp/port7 bash "$serial_tmp/dialog" \
    --title Prompt --menu "mode" 10 40 2 NORMAL normal PATH path \
    </dev/null >/dev/null 2>"$serial_tmp/menu-path-result"
assert_eq "adapter/menu-stderr-result" "PATH" "$(cat "$serial_tmp/menu-path-result")"
exec 8<&-

# Display-only infobox widgets keep their requested text and dimensions on the
# console, do not call dialog.bak, and stay quiet on the serial transcript by
# default.
: >"$serial_tmp/infobox-serial"
SERIAL=$serial_tmp/infobox-serial sh "$serial_tmp/dialog" \
    --title Info --infobox "real progress" 7 50 </dev/null >"$serial_tmp/infobox" 2>&1
assert_eq "adapter/infobox-view-exit" "0" "$?"
assert_fail "adapter/infobox-no-real-dialog" grep -q -- "VIEW " "$serial_tmp/infobox"
assert_ok "adapter/infobox-console" grep -q -- "TITLE: Info" "$serial_tmp/infobox"
assert_eq "adapter/infobox-serial-muted" "" "$(cat "$serial_tmp/infobox-serial")"

: >"$serial_tmp/infobox-serial-unmuted"
SERIAL_INFOBOXES=1 SERIAL=$serial_tmp/infobox-serial-unmuted sh "$serial_tmp/dialog" \
    --title Info --infobox "real progress" 7 50 </dev/null >"$serial_tmp/infobox-unmuted" 2>&1
assert_eq "adapter/infobox-unmuted-exit" "0" "$?"
assert_ok "adapter/infobox-serial-unmuted" grep -q "TITLE: Info" "$serial_tmp/infobox-serial-unmuted"

# Match real dialog status codes for accepted, negative, and escape answers.
mkfifo "$serial_tmp/port5"
exec 8<>"$serial_tmp/port5"
printf 'no\n' >&8
SERIAL=$serial_tmp/port5 sh "$serial_tmp/dialog" \
    --yesno "continue?" 6 40 </dev/null >/dev/null 2>&1
assert_eq "adapter/yesno-no-exit" "1" "$?"
exec 8<&-

mkfifo "$serial_tmp/port6"
exec 8<>"$serial_tmp/port6"
printf 'esc\n' >&8
SERIAL=$serial_tmp/port6 sh "$serial_tmp/dialog" \
    --menu "pick" 10 40 2 first one second two </dev/null >/dev/null 2>&1
assert_eq "adapter/menu-esc-exit" "255" "$?"
exec 8<&-

# Empty menu response selects the highlighted item, like real dialog.
# Run under bash because macOS sh handles echo -n differently.
mkfifo "$serial_tmp/port3"
exec 8<>"$serial_tmp/port3"
printf '\n' >&8
SERIAL=$serial_tmp/port3 bash "$REPO_D/guestlib/dialog.sh" \
    --menu "pick" 10 40 2 first one second two \
    </dev/null >/dev/null 2>"$serial_tmp/menu-result"
assert_eq "adapter/menu-empty-default" "first" "$(cat "$serial_tmp/menu-result")"
exec 8<&-
rm -rf "$serial_tmp"

# --- extract image links ----------------------------------------------------
assert_fail "extract/install-files-propagates-helper-failure" bash -c '
    source "$1/hostlib/logging.sh"
    source "$1/hostlib/extract.sh"
    extract_install_archive_images() { return 1; }
    EXTRACT_SOURCE=source.tgz
    EXTRACT_BOOT_IMAGE=boot.img
    EXTRACT_EXTRA_IMAGES=()
    EXTRACT_FAT_FILES=()
    extract_install_files
' _ "$REPO_D"

extract_tmp=$(mktemp -d)
printf 'boot image\n' >"$extract_tmp/boot.img"
(cd "$extract_tmp" && extract_link_boot_media boot.img)
assert_eq "extract/boot-img-stays-file" "regular file" "$(cd "$extract_tmp" && if [ -f boot.img ] && [ ! -L boot.img ]; then printf 'regular file'; else printf 'other'; fi)"

printf 'kernel image\n' >"$extract_tmp/bare.i"
(cd "$extract_tmp" && extract_link_boot_media bare.i)
assert_eq "extract/boot-img-links-other-name" "bare.i" "$(readlink "$extract_tmp/boot.img")"
rm -rf "$extract_tmp"

# Staged install artifacts come from read-only media on some hosts. They must
# remain writable so later extraction steps, tagfile generation, and QEMU can
# update/open them.
extract_tmp=$(mktemp -d)
mkdir -p "$extract_tmp/fat/packages/a1"
printf 'package\n' >"$extract_tmp/fat/packages/a1/base.tgz"
printf 'boot\n' >"$extract_tmp/boot.img"
chmod 500 "$extract_tmp/fat/packages/a1"
chmod 400 "$extract_tmp/fat/packages/a1/base.tgz" "$extract_tmp/boot.img"
extract_make_user_writable "$extract_tmp/fat" "$extract_tmp/boot.img"
assert_ok "extract/fat-dir-writable" test -w "$extract_tmp/fat/packages/a1"
assert_ok "extract/fat-file-writable" test -w "$extract_tmp/fat/packages/a1/base.tgz"
assert_ok "extract/image-file-writable" test -w "$extract_tmp/boot.img"
rm -rf "$extract_tmp"

# --- Red Hat Kickstart floppy staging ---------------------------------------
if command -v mcopy >/dev/null 2>&1 && command -v mformat >/dev/null 2>&1 && command -v mtype >/dev/null 2>&1; then
    rh_tmp=$(mktemp -d)
    mkdir -p "$rh_tmp/redhat/5.0-infomagic" "$rh_tmp/qemu.d"
    printf '# comment\n\nkickstart\n  # indented comment\n  \n' >"$rh_tmp/redhat/5.0-infomagic/ks.cfg"
    truncate -s 1440k "$rh_tmp/qemu.d/boot.img"
    mformat -i "$rh_tmp/qemu.d/boot.img" ::
    (
        DISTRO_D="$rh_tmp/redhat/5.0-infomagic"
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
        DISTRO_D="$rh_tmp/redhat/5.2-infomagic"
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

(cd "$slack_tmp" && DISTRO_D="$slack_tmp/conf" TEMP_D="$slack_tmp" INSTALL_TAGSETS=max slackware_prepare_tagfiles)

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
    # shellcheck disable=SC2034 # Read by slackware_universe_from_iso.
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
(cd "$slack_tmp2" && DISTRO_D="$slack_tmp2" TEMP_D="$slack_tmp2" INSTALL_TAGSETS=none slackware_prepare_tagfiles)
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
