# unpack the base system
echo "### Installing base system to $ROOTDEV..."
cd $ROOTMOUNT
zcat < $INSTMOUNT/basedsk1.img 2>/dev/null | cpio -dimV
zcat < $INSTMOUNT/basedsk2.img 2>/dev/null | cpio -dimV
mv $ROOTMOUNT/fstab.tmp $ROOTMOUNT/etc/fstab

# change root device in rc scripts
echo "### Configuring init scripts for $ROOTDEV..."
cat $ROOTMOUNT/etc/rc.d/rc.S | 
  sed "s|/dev/hda3|$ROOTDEV|g" > $ROOTMOUNT/tmp/rc.S
chmod 754 $ROOTMOUNT/etc/rc.d/rc.S
mv $ROOTMOUNT/tmp/rc.S $ROOTMOUNT/etc/rc.d/rc.S
cat $ROOTMOUNT/etc/rc.d/rc.K | 
  sed "s|/dev/hda3|$ROOTDEV|g" > $ROOTMOUNT/tmp/rc.K
mv $ROOTMOUNT/tmp/rc.K $ROOTMOUNT/etc/rc.d/rc.K
chmod 754 $ROOTMOUNT/etc/rc.d/rc.S

echo "### Configuring lilo for $ROOTDEV..."
# set root device, read only, and normal vga in kernel
$ROOTMOUNT/usr/sbin/rdev $ROOTMOUNT/vmlinuz $ROOTDEV
$ROOTMOUNT/usr/sbin/rdev -R $ROOTMOUNT/vmlinuz 1
$ROOTMOUNT/usr/sbin/rdev -v $ROOTMOUNT/vmlinuz -1

# change root device in lilo.conf, then install
cat $ROOTMOUNT/etc/lilo.conf | 
  sed "s|/dev/hda3|$ROOTDEV|g" |
  sed "s|read-only|#read-only|g" |
  sed "s|delay=20|#delay=20|g" > $ROOTMOUNT/tmp/lilo.conf
mv $ROOTMOUNT/tmp/lilo.conf $ROOTMOUNT/etc/lilo.conf
$ROOTMOUNT/sbin/lilo -r $ROOTMOUNT -C /etc/lilo.conf

# copy configuration script to new filesystem
$ROOTMOUNT/bin/cp $INSTMOUNT/autoinst.d/autoconf.sh $ROOTMOUNT/sbin/setup.sh
chmod 755 $ROOTMOUNT/sbin/setup.sh