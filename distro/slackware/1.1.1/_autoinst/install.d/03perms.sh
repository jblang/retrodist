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