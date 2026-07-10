script_import ../dinstall.sh

screen_wait -l "boot:"
kb_send_line ""

NET_HOSTNAME=bo
# 1.3 reads the drivers from the mounted medium and logs out at the end of
# first boot.
DRIVER_FLOPPY=
DINSTALL_RELOGIN=true

dinstall_setup
