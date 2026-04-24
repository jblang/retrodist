echo "### Installing packages..."

find /mnt -iname '*.deb' | sort | while read FILE; do
    PKG=$(basename $FILE .deb)
    echo "installing $PKG..."
    (cd /; zcat $FILE 2>>/var/adm/dpkg/dpkg.log | cpio -dim) 2> /dev/null
    if [ -f /var/adm/dpkg/perm/$PKG.perm ]; then
        fixperms -q $PKG 2> /dev/null
    fi
done

for INST in `ls /var/adm/dpkg/inst/*.inst`; do
    if ! egrep -q '\<read\>' $INST ; then
        sh $INST
    fi
    rm -f $INST
done
