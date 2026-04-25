# unpack the base system
echo "### Installing base system to $ROOTDEV..."
cd $TARGETMOUNT
zcat < $SOURCEMOUNT/basedsk1.img 2>/dev/null | cpio -dimV
zcat < $SOURCEMOUNT/basedsk2.img 2>/dev/null | cpio -dimV
mv $TARGETMOUNT/fstab.tmp $TARGETMOUNT/etc/fstab

# change root device in rc scripts
echo "### Configuring init scripts for $ROOTDEV..."
cat $TARGETMOUNT/etc/rc.d/rc.S | 
  sed "s|/dev/hda3|$ROOTDEV|g" > $TARGETMOUNT/tmp/rc.S
chmod 754 $TARGETMOUNT/etc/rc.d/rc.S
mv $TARGETMOUNT/tmp/rc.S $TARGETMOUNT/etc/rc.d/rc.S
cat $TARGETMOUNT/etc/rc.d/rc.K | 
  sed "s|/dev/hda3|$ROOTDEV|g" > $TARGETMOUNT/tmp/rc.K
mv $TARGETMOUNT/tmp/rc.K $TARGETMOUNT/etc/rc.d/rc.K
chmod 754 $TARGETMOUNT/etc/rc.d/rc.S

echo "### Configuring lilo for $ROOTDEV..."
# set root device, read only, and normal vga in kernel
$TARGETMOUNT/usr/sbin/rdev $TARGETMOUNT/vmlinuz $ROOTDEV
$TARGETMOUNT/usr/sbin/rdev -R $TARGETMOUNT/vmlinuz 1
$TARGETMOUNT/usr/sbin/rdev -v $TARGETMOUNT/vmlinuz -1

# change root device in lilo.conf, then install
cat $TARGETMOUNT/etc/lilo.conf | 
  sed "s|/dev/hda3|$ROOTDEV|g" |
  sed "s|read-only|#read-only|g" |
  sed "s|delay=20|#delay=20|g" > $TARGETMOUNT/tmp/lilo.conf
mv $TARGETMOUNT/tmp/lilo.conf $TARGETMOUNT/etc/lilo.conf
$TARGETMOUNT/sbin/lilo -r $TARGETMOUNT -C /etc/lilo.conf

# copy configuration script to new filesystem
$TARGETMOUNT/bin/cp $SOURCEMOUNT/autoinst.d/autoconf.sh $TARGETMOUNT/sbin/setup.sh
chmod 755 $TARGETMOUNT/sbin/setup.sh