echo "## initializing swap..."
mkswap $SWAPDEVICE $SWAPSIZE
swapon $SWAPDEVICE

echo "## initializing root filesystem..."
mke2fs $ROOTDEVICE
mount -t $ROOTFSTYPE $ROOTDEVICE $ROOTMOUNT

# set up fstab
cat > $ROOTMOUNT/fstab.tmp <<EOF
$ROOTDEVICE		/		$ROOTFSTYPE	defaults
$SWAPDEVICE		swap	swap		defaults
none			/proc	proc		defaults
EOF