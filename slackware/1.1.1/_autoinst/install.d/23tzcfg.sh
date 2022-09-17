echo "## setting timezone to $TIMEZONE..."
( cd $ROOTMOUNT/usr/lib/zoneinfo ; ln -sf $TIMEZONE localtime )
mv $ROOTMOUNT/usr/adm/setup/setup.timeconfig $ROOTMOUNT/usr/adm/setup/install