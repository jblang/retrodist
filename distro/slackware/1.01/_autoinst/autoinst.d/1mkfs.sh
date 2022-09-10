echo "### initializing swap..."
mkswap $SWAPDEVICE $SWAPSIZE
swapon $SWAPDEVICE

echo "### initializing root filesystem..."
mke2fs $ROOTDEVICE
mount -t ext2 $ROOTDEVICE $ROOTMOUNT