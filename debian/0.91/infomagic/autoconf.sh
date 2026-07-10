sh "$AUTOINST_D/deb091/pkginst.sh" "$INSTMOUNT"

tty_config

X11_MOUSEDEV=/dev/cua2
x11_config
