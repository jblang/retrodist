script_import ../dialog-setup.sh

screen_wait -l "boot:"
kb_send_line ""
dialog_setup
