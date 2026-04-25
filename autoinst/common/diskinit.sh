echo "### Creating partitions..."
for FDFILE in $SOURCEMOUNT/autoinst.d/fdisk.*; do
    FDDEV=$(echo $FDFILE | sed "s,$SOURCEMOUNT/autoinst\.d/fdisk\.,,g")
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

mount -t $ROOTFS $ROOTDEV $TARGETMOUNT
mkdir -p $TARGETMOUNT/tmp

echo "### Creating fstab..."
cat > $TARGETMOUNT/fstab.tmp <<EOF
$ROOTDEV		/		$ROOTFS	defaults	0	1
$SWAPDEV		none		swap		sw		0	0
none			/proc		proc		defaults	0	0
EOF
