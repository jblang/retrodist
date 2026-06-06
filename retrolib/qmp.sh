# shellcheck shell=bash
# QMP helpers for querying QEMU state.

QMP_LIBDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
QMP_VGA_DECODE_AWK=${QMP_VGA_DECODE_AWK:-$QMP_LIBDIR/vgadecode.awk}

# Sets default QMP connection and VGA dump settings.
qmp_set_defaults() {
  QMP_HOST=${QMP_HOST:-127.0.0.1}
  QMP_PORT=${QMP_PORT:-${QEMU_QMP_PORT:-$(( ${QEMU_TELNET_BASE_PORT:-2300} + 8 ))}}
  QMP_TIMEOUT=${QMP_TIMEOUT:-1}

  VGA_ADDR=${VGA_ADDR:-0xb8000}
  VGA_COLS=${VGA_COLS:-80}
  VGA_ROWS=${VGA_ROWS:-25}
  VGA_MEM_BYTES=${VGA_MEM_BYTES:-32768}
}

# Verifies commands and decoder files required by the QMP helpers.
qmp_check_prereqs() {
  if ! command -v nc >/dev/null 2>&1; then
    echo "Missing nc in PATH" >&2
    return 1
  fi

  if ! command -v awk >/dev/null 2>&1; then
    echo "Missing awk in PATH" >&2
    return 1
  fi

  if [ ! -r "$QMP_VGA_DECODE_AWK" ]; then
    echo "Missing QMP VGA decoder: $QMP_VGA_DECODE_AWK" >&2
    return 1
  fi
}

# Initializes QMP defaults, prerequisites, and VGA settings.
qmp_init() {
  qmp_set_defaults
  qmp_check_prereqs
  qmp_vga_validate_config
}

# Validates numeric VGA configuration used when decoding screen memory.
qmp_vga_validate_config() {
  case "$VGA_COLS:$VGA_ROWS:$VGA_MEM_BYTES" in
    *[!0-9:]* | :* | *:)
      echo "VGA_COLS, VGA_ROWS, and VGA_MEM_BYTES must be positive integers" >&2
      return 1
      ;;
  esac

}

# Tests whether the QEMU process for this install is still running.
qmp_qemu_running() {
  local state

  [ -n "${QEMU_PID:-}" ] || return 0
  state=$(ps -p "$QEMU_PID" -o stat= 2>/dev/null) || return 1
  [[ $state != Z* ]]
}

# Sends a human monitor command through QMP.
qmp_hmp_command() {
  {
    printf '{"execute":"qmp_capabilities"}\n'
    printf '{"execute":"human-monitor-command","arguments":{"command-line":"%s"}}\n' "$1"
  } | nc -w "$QMP_TIMEOUT" "$QMP_HOST" "$QMP_PORT"
}

qmp_eject_disk() {
  local device
  device=${1:-floppy0}

  qmp_hmp_command "eject $device" >/dev/null
}

# Changes the configured floppy device to the given image.
qmp_change_image() {
  local image device
  image=$1
  device=${2:-floppy0}

  qmp_hmp_command "change $device $image" >/dev/null
}

# Sets the QEMU boot device order.
qmp_boot_disk() {
  qmp_hmp_command "boot_set $1" >/dev/null
}

# Dumps bytes from an address with the QEMU xp command.
qmp_dump_memory() {
  qmp_hmp_command "xp /${2}xb $1"
}

# Sends a QEMU sendkey key sequence.
qmp_sendkey() {
  qmp_hmp_command "sendkey $1" >/dev/null
}

# Sends the Return key to the guest.
qmp_send_return() {
  qmp_sendkey ret
}

# Converts one character to a QEMU sendkey token.
qmp_char_to_sendkey() {
  case "$1" in
    [a-z]|[0-9]) printf '%s' "$1" ;;
    [A-Z]) printf 'shift-%s' "$1" | tr '[:upper:]' '[:lower:]' ;;
    $'\t') printf 'tab' ;;
    $'\n') printf 'ret' ;;
    $'\\') printf 'backslash' ;;
    ' ') printf 'spc' ;;
    '!') printf 'shift-1' ;;
    '@') printf 'shift-2' ;;
    '#') printf 'shift-3' ;;
    '$') printf 'shift-4' ;;
    '%') printf 'shift-5' ;;
    '^') printf 'shift-6' ;;
    '&') printf 'shift-7' ;;
    '*') printf 'shift-8' ;;
    '(') printf 'shift-9' ;;
    ')') printf 'shift-0' ;;
    '-') printf 'minus' ;;
    '_') printf 'shift-minus' ;;
    '=') printf 'equal' ;;
    '+') printf 'shift-equal' ;;
    '[') printf 'bracket_left' ;;
    '{') printf 'shift-bracket_left' ;;
    ']') printf 'bracket_right' ;;
    '}') printf 'shift-bracket_right' ;;
    '|') printf 'shift-backslash' ;;
    ';') printf 'semicolon' ;;
    ':') printf 'shift-semicolon' ;;
    "'") printf 'apostrophe' ;;
    '"') printf 'shift-apostrophe' ;;
    '`') printf 'grave_accent' ;;
    '~') printf 'shift-grave_accent' ;;
    ',') printf 'comma' ;;
    '<') printf 'shift-comma' ;;
    '.') printf 'dot' ;;
    '>') printf 'shift-dot' ;;
    '/') printf 'slash' ;;
    '?') printf 'shift-slash' ;;
    *) return 1 ;;
  esac
  return 0
}

# Types a string into the guest using QEMU sendkey.
qmp_send_string() {
  local text i char key
  text=$1

  for ((i = 0; i < ${#text}; i++)); do
    char=${text:i:1}
    key=$(qmp_char_to_sendkey "$char") || return 1
    qmp_sendkey "$key"
  done
}

# Types a line into the guest and presses Return.
qmp_send_line() {
  qmp_send_string "$1"
  qmp_send_return
}

# Reads stdin and types it into the guest.
qmp_send_stdin() {
  local char key

  # Read one byte at a time so trailing newlines are preserved.
  while IFS= read -r -n 1 char; do
    if [ -z "$char" ]; then
      char=$'\n'
    fi
    key=$(qmp_char_to_sendkey "$char") || return 1
    qmp_sendkey "$key"
  done
}

# Decodes a QEMU xp byte dump into plain VGA text.
qmp_vga_decode_text() {
  awk -v cols="$VGA_COLS" -v needed="$VGA_MEM_BYTES" -f "$QMP_VGA_DECODE_AWK"
}

# Dumps VGA memory and decodes it as text.
qmp_vga_dump_text() {
  qmp_dump_memory "$VGA_ADDR" "$VGA_MEM_BYTES" | qmp_vga_decode_text
}
