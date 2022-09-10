echo '### performing $INSTTYPE install; please wait...'

mkdir -p $ROOTMOUNT/install/installed
mkdir -p $ROOTMOUNT/install/disks
mkdir -p $ROOTMOUNT/install/scripts
mkdir -p $ROOTMOUNT/install/catalog
echo "$ROOTDEVICE	/		$ROOTFSTYPE	defaults" > $ROOTMOUNT/fstab.tmp
sysinstall -instdev $INSTDEV -instsrc $INSTSRC -instroot $ROOTMOUNT -$INSTTYPE
mv $ROOTMOUNT/fstab.tmp $ROOTMOUNT/etc/fstab