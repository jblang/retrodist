# shellcheck shell=bash
# Reusable QMP-driven install script building blocks.

script_boot_lilo() {
  qmp_wait_prompt "${1:-boot:}"
  qmp_send_return
}

script_change_floppy() {
  local prompt image
  prompt=$1
  image=${2:-root.img}

  qmp_wait_screen "$prompt"
  qmp_change_floppy "$image"
  sleep 1
  qmp_send_return
}

script_press_enter_on_screen() {
  qmp_wait_screen "$1"
  qmp_send_return
}

script_wait_screen() {
  qmp_wait_screen "$1"
}

script_press_key() {
  qmp_sendkey "$1"
}

script_login() {
  local prompt user
  prompt=$1
  user=${2:-root}

  qmp_wait_prompt "$prompt"
  qmp_send_line "$user"
}

script_run_autoinst() {
  qmp_wait_prompt "$1"
  qmp_send_line "mkdir /retro && mount -t msdos /dev/hdb1 /retro && /retro/autoinst"
}

script_run_autoinst_when_screen() {
  qmp_wait_screen "$1"
  qmp_send_line "mkdir /retro && mount -t msdos /dev/hdb1 /retro && /retro/autoinst"
}

script_finish_reboot() {
  qmp_wait_screen "${1:-Press ENTER to reboot.}" "${2:-600}"
  qmp_boot_set c
  qmp_send_return
}
