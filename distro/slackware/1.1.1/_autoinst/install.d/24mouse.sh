echo "## setting mouse device..."
( cd $ROOTMOUNT/dev; ln -sf ps2aux mouse )
mv $ROOTMOUNT/usr/adm/setup/setup.selection $ROOTMOUNT/usr/adm/setup/install