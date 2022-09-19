echo "## installing base system..."
cd $ROOTMOUNT
zcat < /mnt/basedsk1.img 2>/dev/null | cpio -dimV
zcat < /mnt/basedsk2.img 2>/dev/null | cpio -dimV
