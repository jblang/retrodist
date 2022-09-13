echo "### installing packages..."
SETS=$(echo $SETS | sed 's/[ ;,]/#/g')
pkgtool -source_mounted -ignore_tagfiles -source_device $INSTDEV -source_dir $INSTSRC -target_dir $ROOTMOUNT -sets "#$SETS#"
if [ ! -r $ROOTMOUNT/etc/rc.d/ROOTDEV ]; then
  echo "$ROOTDEVICE" > $ROOTMOUNT/etc/rc.d/ROOTDEV
  chmod 644 $ROOTMOUNT/etc/rc.d/ROOTDEV
fi
if [ ! -r $ROOTMOUNT/sbin/pkgtool ]; then
  cp /bin/pkgtool $ROOTMOUNT/sbin/pkgtool
  cp /bin/setup $ROOTMOUNT/sbin/setup
  chmod 755 $ROOTMOUNT/sbin/pkgtool $ROOTMOUNT/sbin/setup
fi
if [ ! -r $ROOTMOUNT/etc/fstab ]; then
  mv $ROOTMOUNT/fstab.tmp $ROOTMOUNT/etc/fstab
  chmod 644 $ROOTMOUNT/etc/fstab
fi
if [ ! -d $ROOTMOUNT/usr/adm/setup/install ]; then
  mkdir $ROOTMOUNT/usr/adm/setup/install
fi
