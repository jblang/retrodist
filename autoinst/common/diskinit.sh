echo "### Creating partitions..."
for FDFILE in $INSTMOUNT/autoinst.d/fdisk.*; do
    FDDEV=$(echo $FDFILE | sed "s,$INSTMOUNT/autoinst\.d/fdisk\.,,g")
    fdisk /dev/$FDDEV < $FDFILE > /dev/null
done
fdisk -l

echo "### Initializing swap..."
mkswap $SWAPDEV $SWAPSIZE
swapon $SWAPDEV

echo "### Initializing root filesystem..."
case $ROOTFS in
    ext2 )  mke2fs $ROOTDEV ;;
    * )     echo "Unknown filesystem $ROOTFS"; exit 1;;
esac

mount -t $ROOTFS $ROOTDEV $ROOTMOUNT
mkdir -p $ROOTMOUNT/tmp

echo "### Creating fstab..."
cat > $ROOTMOUNT/fstab.tmp <<EOF
$ROOTDEV		/		$ROOTFS	defaults
$SWAPDEV		swap	swap		defaults
none			/proc	proc		defaults
EOF