echo "### Installing packages..."

# install packages
for FILE in `ls /mnt/packages/*.deb`; do
    # do this without dpkg to avoid interactive prompts
    # internally, dpkg is a script that runs `zcat | cpio -dim`
    PKG=$(basename $FILE .deb)
    echo "installing $PKG..."
    (cd /; zcat $FILE 2>>/var/adm/dpkg/dpkg.log | cpio -dim) 2> /dev/null
    if [ -f /var/adm/dpkg/perm/$PKG.perm ]; then
        fixperms -q $PKG 2> /dev/null
    fi
done

# run install scripts
for INST in `ls /var/adm/dpkg/inst/*.inst`; do
    # skip any scripts with interactive prompts
    if ! egrep -q '\<read\>' $INST ; then
        sh $INST
    fi
    rm -f $INST
done
