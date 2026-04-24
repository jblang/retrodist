DEBIAN_BASE_DISKS="basedsk1 basedsk2 basedsk3"
DEBIAN_PREPARE_FUNCTION=prepare_base_system_093r6
DEBIAN_ROOT_HOOK=.configure
DEBIAN_OPTIONAL_LILO=1

. "$INSTMOUNT/autoinst.d/debian/baseinst/dinstall.sh"
