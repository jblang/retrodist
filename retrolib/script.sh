# shellcheck shell=bash
# Reusable QMP-driven install script building blocks.

# Waits until VGA text memory contains expected screen text.
script_wait_screen() {
  local screen text timeout interval start
  text=$1
  timeout=${2:-${WAIT_TIMEOUT:-60}}
  interval=${3:-${WAIT_INTERVAL:-1}}
  start=$SECONDS

  while :; do
    if ! qmp_qemu_running; then
      echo "QEMU exited while waiting for screen text: $text" >&2
      exit 1
    fi

    if screen=$(qmp_vga_dump_text); then
      if grep -F "$text" <<< "$screen" >/dev/null; then
        return 0
      fi
    fi

    if [ "$timeout" != "0" ] && [ $((SECONDS - start)) -ge "$timeout" ]; then
      echo "Timed out waiting for screen text: '$text'" >&2
      exit 124
    fi

    sleep "$interval"
  done
}

# Waits for a LILO prompt and presses Return.
script_boot_lilo() {
  script_wait_screen "${1:-boot:}"
  qmp_send_return
}

# Waits for a prompt and sends an optional answer.
script_answer_prompt() {
  local prompt answer
  prompt=$1
  answer=${2:-}
  script_wait_screen "$prompt"
  if [[ -n "$answer" ]]; then
    qmp_send_line "$answer"
  else
    qmp_send_return
  fi
}

# Swaps the first floppy image while answering an installer prompt.
script_change_floppy() {
  local prompt image answer
  prompt=$1
  image=${2:-root.img}
  answer=${3:-}

  script_wait_screen "$prompt"
  qmp_change_image "$image"
  sleep 1
  if [[ -n "$answer" ]]; then
    qmp_send_string "$answer"
  fi
  qmp_send_return
}

# Sends one QEMU sendkey token to the guest.
script_press_key() {
  qmp_sendkey "$1"
}

# Sends Return to the guest.
script_send_return() {
  qmp_send_return
}

# Waits for a login prompt and enters a username.
script_login() {
  local prompt user
  prompt=$1
  user=${2:-root}

  script_wait_screen "$prompt"
  qmp_send_line "$user"
}

# Mounts the staged FAT media and launches the autoinstall script.
script_run_autoinst() {
  script_wait_screen "$1"
  qmp_send_line "mkdir /retro && mount -t msdos /dev/hdb1 /retro && sh /retro/autoinst"
}

# Sets the next boot device and confirms the final reboot prompt.
script_finish_reboot() {
  local disk prompt timeout
  disk="${1:-c}"
  prompt="${2:-Press ENTER to reboot.}"
  timeout="${3:-600}"
  script_wait_screen "$prompt" "$timeout"
  qmp_boot_disk "$disk"
  qmp_send_return
}
