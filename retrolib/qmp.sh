# shellcheck shell=bash
# QMP helpers for querying QEMU state.

qmp_set_defaults() {
  QMP_HOST=${QMP_HOST:-127.0.0.1}
  QMP_PORT=${QMP_PORT:-${QEMU_QMP_PORT:-$(( ${QEMU_TELNET_BASE_PORT:-2300} + 8 ))}}
  QMP_TIMEOUT=${QMP_TIMEOUT:-1}

  VGA_ADDR=${VGA_ADDR:-0xb8000}
  VGA_COLS=${VGA_COLS:-80}
  VGA_ROWS=${VGA_ROWS:-25}
  VGA_MEM_BYTES=${VGA_MEM_BYTES:-32768}
  VGA_LINE_NUMBERS=${VGA_LINE_NUMBERS:-0}
}

qmp_check_prereqs() {
  if ! command -v nc >/dev/null 2>&1; then
    echo "Missing nc in PATH" >&2
    return 1
  fi

  if ! command -v awk >/dev/null 2>&1; then
    echo "Missing awk in PATH" >&2
    return 1
  fi
}

qmp_init() {
  qmp_set_defaults
  qmp_check_prereqs
  qmp_vga_validate_config
}

qmp_vga_validate_config() {
  case "$VGA_COLS:$VGA_ROWS:$VGA_MEM_BYTES" in
    *[!0-9:]* | :* | *:)
      echo "VGA_COLS, VGA_ROWS, and VGA_MEM_BYTES must be positive integers" >&2
      return 1
      ;;
  esac

  case "$VGA_LINE_NUMBERS" in
    0 | 1) ;;
    *)
      echo "VGA_LINE_NUMBERS must be 0 or 1" >&2
      return 1
      ;;
  esac
}

qmp_hmp_command() {
  {
    printf '{"execute":"qmp_capabilities"}\n'
    printf '{"execute":"human-monitor-command","arguments":{"command-line":"%s"}}\n' "$1"
  } | nc -w "$QMP_TIMEOUT" "$QMP_HOST" "$QMP_PORT"
}

qmp_change_floppy() {
  local image device
  image=$1
  device=${QMP_FLOPPY_DEVICE:-floppy0}

  qmp_hmp_command "change $device $image" >/dev/null
}

qmp_eject_floppy() {
  local device
  device=${QMP_FLOPPY_DEVICE:-floppy0}

  qmp_hmp_command "eject $device" >/dev/null
}

qmp_eject_cdrom() {
  local device
  device=${QMP_CDROM_DEVICE:-ide1-cd0}

  qmp_hmp_command "eject $device" >/dev/null
}

qmp_boot_set() {
  qmp_hmp_command "boot_set $1" >/dev/null
}

qmp_sendkey() {
  qmp_hmp_command "sendkey $1" >/dev/null
}

qmp_send_return() {
  qmp_sendkey ret
}

qmp_char_to_sendkey() {
  case "$1" in
    [a-z]) echo $1 ;;
    [A-Z]) echo "shift-$(echo $1 | tr A-Z a-z)" ;;
    ' ') echo spc ;;
    $'\t') echo tab ;;
    $'\n') echo ret ;;
    [0-9]) echo $1 ;;
    '!') echo shift-1 ;; 
    '@') echo shift-2 ;; 
    '#') echo shift-3 ;;
    '$') echo shift-4 ;; 
    '%') echo shift-5 ;; 
    '^') echo shift-6 ;;
    '&') echo shift-7 ;; 
    '*') echo shift-8 ;; 
    '(') echo shift-9 ;;
    ')') echo shift-0 ;;
    '-') echo minus ;; 
    '_') echo shift-minus ;;
    '=') echo equal ;; 
    '+') echo shift-equal ;;
    '[') echo bracket_left ;; 
    '{') echo shift-bracket_left ;;
    ']') echo bracket_right ;; 
    '}') echo shift-bracket_right ;;
    $'\\') echo backslash ;; 
    '|') echo shift-backslash ;;
    ';') echo semicolon ;; 
    ':') echo shift-semicolon ;;
    "'") echo apostrophe ;; 
    '"') echo shift-apostrophe ;;
    '`') echo grave_accent ;; 
    '~') echo shift-grave_accent ;;
    ',') echo comma ;; 
    '<') echo shift-comma ;;
    '.') echo dot ;; 
    '>') echo shift-dot ;;
    '/') echo slash ;; 
    '?') echo shift-slash ;;
    *) return 1 ;;
  esac
  return 0;
}

qmp_send_string() {
  local text i char key
  text=$1

  for ((i = 0; i < ${#text}; i++)); do
    char=${text:i:1}
    key=$(qmp_char_to_sendkey "$char") || return 1
    qmp_sendkey "$key"
  done
}

qmp_send_line() {
  qmp_send_string "$1"
  qmp_send_return
}

qmp_send_stdin() {
  local char key

  while IFS= read -r -n 1 char; do
    if [ -z "$char" ]; then
      char=$'\n'
    fi
    key=$(qmp_char_to_sendkey "$char") || return 1
    qmp_sendkey "$key"
  done
}

qmp_vga_byte_count() {
  echo ${VGA_DUMP_BYTES:-$((VGA_COLS * VGA_ROWS * 2))}
}

qmp_vga_xp_command() {
  printf 'xp /%sxb %s\n' "$(qmp_vga_byte_count)" "${VGA_DUMP_ADDR:-$VGA_ADDR}"
}

qmp_vga_decode_xp_response() {
  awk -v cols="$VGA_COLS" -v needed="$(qmp_vga_byte_count)" -v line_numbers="$VGA_LINE_NUMBERS" '
function hex_digit(c) {
  c = tolower(c)
  return index("0123456789abcdef", c) - 1
}

function hex_byte(h) {
  return hex_digit(substr(h, 1, 1)) * 16 + hex_digit(substr(h, 2, 1))
}

function screen_char(v) {
  if (v == 0 || v == 32) return " "
  if (v >= 32 && v <= 126) return sprintf("%c", v)
  return "."
}

{
  line = $0
  while (match(line, /0x[0-9a-fA-F][0-9a-fA-F]/)) {
    byte_count++
    if (byte_count % 2 == 1) {
      out = out screen_char(hex_byte(substr(line, RSTART + 2, 2)))
      char_count++
      if (char_count % cols == 0) {
        row_count++
        if (line_numbers) {
          printf "%02d: %s\n", row_count, out
        } else {
          print out
        }
        out = ""
      }
    }
    if (byte_count >= needed) exit
    line = substr(line, RSTART + RLENGTH)
  }
}

END {
  if (out != "") {
    row_count++
    if (line_numbers) {
      printf "%02d: %s\n", row_count, out
    } else {
      print out
    }
  }

  if (byte_count < needed) {
    printf "QMP xp returned only %d bytes; expected %d\n", byte_count, needed > "/dev/stderr"
    exit 1
  }
}
'
}

qmp_vga_dump_text_raw() {
  qmp_hmp_command "$(qmp_vga_xp_command)" | qmp_vga_decode_xp_response
}

qmp_vga_memory_text() {
  local dump_addr dump_bytes text_status
  dump_addr=${VGA_DUMP_ADDR:-}
  dump_bytes=${VGA_DUMP_BYTES:-}
  VGA_DUMP_ADDR=$VGA_ADDR
  VGA_DUMP_BYTES=$VGA_MEM_BYTES
  qmp_vga_dump_text_raw
  text_status=$?
  if [ -n "$dump_addr" ]; then
    VGA_DUMP_ADDR=$dump_addr
  else
    unset VGA_DUMP_ADDR
  fi
  if [ -n "$dump_bytes" ]; then
    VGA_DUMP_BYTES=$dump_bytes
  else
    unset VGA_DUMP_BYTES
  fi
  return "$text_status"
}

qmp_vga_text() {
  qmp_vga_memory_text
}

qmp_vga_screen_memory_text() {
  local cols line_numbers status
  cols=$VGA_COLS
  line_numbers=$VGA_LINE_NUMBERS
  VGA_COLS=80
  VGA_LINE_NUMBERS=0
  qmp_vga_memory_text
  status=$?
  VGA_COLS=$cols
  VGA_LINE_NUMBERS=$line_numbers
  return "$status"
}

qmp_vga_number_lines() {
  awk '{ printf "%02d: %s\n", NR, $0 }'
}

qmp_last_nonempty_line() {
  awk '
    {
      line = $0
      sub(/[[:space:]]+$/, "", line)
      if (line != "") last = line
    }
    END {
      if (last != "") print last
    }
  '
}

qmp_vga_last_line_has_prompt() {
  local prompt screen last line_numbers
  prompt=$1
  line_numbers=$VGA_LINE_NUMBERS
  VGA_LINE_NUMBERS=0
  screen=$(qmp_vga_text)
  VGA_LINE_NUMBERS=$line_numbers
  last=$(printf '%s\n' "$screen" | qmp_last_nonempty_line)
  [ "$last" = "$prompt" ]
}

qmp_vga_memory_has_text() {
  qmp_vga_memory_grep_text "$1" >/dev/null
}

qmp_vga_memory_grep_text() {
  qmp_vga_screen_memory_text | grep -F "$1"
}

qmp_vga_memory_last_line_has_prompt() {
  local prompt screen last
  prompt=$1
  screen=$(qmp_vga_screen_memory_text)
  last=$(printf '%s\n' "$screen" | qmp_last_nonempty_line)
  [ "$last" = "$prompt" ]
}

qmp_vga_wait_prompt() {
  local prompt timeout interval start
  prompt=$1
  timeout=${2:-60}
  interval=${3:-1}
  start=$SECONDS

  while :; do
    if qmp_vga_memory_has_text "$prompt"; then
      return 0
    fi

    if [ "$timeout" != "0" ] && [ $((SECONDS - start)) -ge "$timeout" ]; then
      return 1
    fi

    sleep "$interval"
  done
}

qmp_wait_prompt() {
  qmp_vga_wait_prompt "$1" "${2:-${WAIT_TIMEOUT:-120}}" "${3:-${WAIT_INTERVAL:-1}}"
}

qmp_wait_screen() {
  local text timeout interval start
  text=$1
  timeout=${2:-${WAIT_TIMEOUT:-120}}
  interval=${3:-${WAIT_INTERVAL:-1}}
  start=$SECONDS

  while :; do
    if qmp_vga_memory_has_text "$text"; then
      return 0
    fi

    if [ "$timeout" != "0" ] && [ $((SECONDS - start)) -ge "$timeout" ]; then
      echo "Timed out waiting for screen text: $text" >&2
      qmp_vga_screen_memory_text | qmp_vga_number_lines >&2 || true
      return 1
    fi

    sleep "$interval"
  done
}
