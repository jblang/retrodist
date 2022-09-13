echo "# installing lilo..."
echo 2 | $ROOTMOUNT/sbin/liloconfig $ROOTMOUNT $ROOTDEVICE
mv $ROOTMOUNT/usr/adm/setup/setup.liloconfig $ROOTMOUNT/usr/adm/setup/install