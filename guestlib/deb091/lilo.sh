#!/bin/sh
# lilo installer for Debian 0.91

ROOTDEV=${1:-/dev/hda2}
ROOTMOUNT=${2:-/root}

echo "Configuring kernel for $ROOTDEV..."
"$ROOTMOUNT/usr/sbin/rdev" "$ROOTMOUNT/vmlinuz" "$ROOTDEV"
"$ROOTMOUNT/usr/sbin/rdev" -R "$ROOTMOUNT/vmlinuz" 1
"$ROOTMOUNT/usr/sbin/rdev" -v "$ROOTMOUNT/vmlinuz" -1

# Point the stock lilo.conf at the real root device and drop its boot delay.
echo "Editing $ROOTMOUNT/etc/lilo.conf"
sed "s|/dev/hda3|$ROOTDEV|g" "$ROOTMOUNT/etc/lilo.conf" |
    sed "s|read-only|#read-only|g" |
    sed "s|delay=20|#delay=20|g" >"$ROOTMOUNT/tmp/lilo.conf"
mv "$ROOTMOUNT/tmp/lilo.conf" "$ROOTMOUNT/etc/lilo.conf"
echo "Running lilo"
"$ROOTMOUNT/sbin/lilo" -r "$ROOTMOUNT" -C /etc/lilo.conf
