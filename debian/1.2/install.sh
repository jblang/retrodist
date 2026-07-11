script_import ../dinstall.sh

vga_wait -l "boot:"
kb_send_line ""

NET_HOSTNAME=rex

dinstall_setup
