echo "## installing lilo..."
cat $ROOTMOUNT/etc/lilo.conf | 
  sed "s|/dev/hda3|$ROOTDEVICE|" > $ROOTMOUNT/etc/lilo.new
mv $ROOTMOUNT/etc/lilo.new $ROOTMOUNT/etc/lilo.conf
$ROOTMOUNT/usr/sbin/chroot $ROOTMOUNT /sbin/lilo
