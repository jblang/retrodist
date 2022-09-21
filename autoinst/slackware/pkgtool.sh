# installer for pkgtool-based versions (1.1.1+)
echo "### installing packages..."
SETS=$(echo $SETS | sed 's/[ ;,]/#/g')
pkgtool -source_mounted -ignore_tagfiles -source_dir $INSTMOUNT -target_dir $ROOTMOUNT -sets "#$SETS#"
if [ ! -r $ROOTMOUNT/etc/rc.d/ROOTDEV ]; then
  echo "$ROOTDEV" > $ROOTMOUNT/etc/rc.d/ROOTDEV
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

echo "### fixing permissions..."
( cd $ROOTMOUNT ; chmod 755 ./ )
( cd $ROOTMOUNT ; chmod 755 ./var )
if [ -d $ROOTMOUNT/usr/src/linux ]; then
  chmod 755 $ROOTMOUNT/usr/src/linux
fi
if [ ! -d $ROOTMOUNT/proc ]; then
  mkdir $ROOTMOUNT/proc
  chown root.root $ROOTMOUNT/proc
fi
if [ ! -L $ROOTMOUNT/lib/cpp ]; then
  ( cd $ROOTMOUNT/lib; ln -sf /usr/lib/gcc-lib/i486-linux/*.*.*/cpp cpp )
fi
if [ ! -d $ROOTMOUNT/usr/spool/uucp ]; then
  mkdir -p $ROOTMOUNT/usr/spool/uucp
fi
chown uucp.uucp $ROOTMOUNT/usr/spool/uucp
chmod 1777 $ROOTMOUNT/usr/spool/uucp
if [ ! -d $ROOTMOUNT/usr/spool/uucppublic ]; then
  mkdir -p $ROOTMOUNT/usr/spool/uucppublic
fi
chown uucp.uucp $ROOTMOUNT/usr/spool/uucppublic
chmod 1777 $ROOTMOUNT/usr/spool/uucppublic
chmod 1777 $ROOTMOUNT/tmp
if [ ! -d $ROOTMOUNT/usr/spool/mail ]; then
  mkdir -p $ROOTMOUNT/usr/spool/mail
  chmod 755 $ROOTMOUNT/usr/spool
  chown root.mail $ROOTMOUNT/usr/spool/mail
  chmod 775 $ROOTMOUNT/usr/spool/mail
fi

echo "### setting timezone to $TIMEZONE..."
( cd $ROOTMOUNT/usr/lib/zoneinfo ; ln -sf $TIMEZONE localtime )
mv $ROOTMOUNT/usr/adm/setup/setup.timeconfig $ROOTMOUNT/usr/adm/setup/install

echo "### installing lilo..."
echo 2 | $ROOTMOUNT/sbin/liloconfig $ROOTMOUNT $ROOTDEV
mv $ROOTMOUNT/usr/adm/setup/setup.liloconfig $ROOTMOUNT/usr/adm/setup/install

# set up autoconf script to run on first boot
cp $INSTMOUNT/autoinst.d/autoconf.sh $ROOTMOUNT
chmod +x $ROOTMOUNT/autoconf.sh
echo "if [ -x /autoconf.sh ]; then" >> $ROOTMOUNT/etc/rc.d/rc.local
echo "  /autoconf.sh" >> $ROOTMOUNT/etc/rc.d/rc.local
echo "fi" >> $ROOTMOUNT/etc/rc.d/rc.local