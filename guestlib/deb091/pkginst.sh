#!/bin/sh
# Debian 0.91 package installer

INSTALL_D=${1:-/mnt}

# Unpack one .deb into / and restore its recorded permissions.
deb_install() {
    PKG=$(basename "$1" .deb)
    echo "Installing $PKG..."
    (
        cd /
        zcat "$1" 2>>/var/adm/dpkg/dpkg.log | cpio -dim
    ) 2>/dev/null
    if [ -f "/var/adm/dpkg/perm/$PKG.perm" ]; then
        fixperms -q "$PKG" 2>/dev/null
    fi
}

echo "Installing packages under $INSTALL_D/packages"
find "$INSTALL_D/packages" -iname '*.deb' | sort | while read FILE; do
    deb_install "$FILE"
done

# Run each package's install script, skipping any that would ask a question.
for INST in $(ls /var/adm/dpkg/inst/*.inst); do
    egrep -q '\<read\>' "$INST"
    if [ $? -ne 0 ]; then
        sh "$INST"
    fi
    rm -f "$INST"
done
