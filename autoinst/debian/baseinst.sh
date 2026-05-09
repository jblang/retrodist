set_debian_baseinst_path() {
    PATH=/usr/bin:/bin:/usr/sbin:/sbin
}

set_file_mode() {
    chown root.root $1
    chmod 644 $1
}

has_cmd() {
    [ -x "/bin/$1" ] || [ -x "/usr/bin/$1" ] || [ -x "/sbin/$1" ] || [ -x "/usr/sbin/$1" ]
}

gzip_extract_cmd() {
    if has_cmd gunzip; then
        echo gunzip
    elif has_cmd zcat; then
        echo zcat
    else
        return 1
    fi
}

extract_tar_stream() {
    if [ -n "$DEBIAN_TAR_EXTRACTOR" ]; then
        set -- $DEBIAN_TAR_EXTRACTOR
        "$@"
    elif has_cmd star; then
        star
    elif has_cmd tar; then
        tar -xpf -
    else
        return 1
    fi
}

prepare_base_system_dinstall() {
    if [ -f /etc/unconf.sh ]; then
        cp /etc/unconf.sh $ROOTMOUNT/sbin/unconfigured.sh
    fi

    if [ -f "$ROOTMOUNT/etc/inittab" ]; then
        mv "$ROOTMOUNT/etc/inittab" "$ROOTMOUNT/etc/inittab.real"
    elif [ -n "$DEBIAN_INITTAB_FALLBACK" ] && [ -f "$ROOTMOUNT/$DEBIAN_INITTAB_FALLBACK" ]; then
        mv "$ROOTMOUNT/$DEBIAN_INITTAB_FALLBACK" "$ROOTMOUNT/etc/inittab.real"
    fi

    if [ -f /etc/init_tab ]; then
        cp /etc/init_tab $ROOTMOUNT/etc/inittab
    elif [ -f "$ROOTMOUNT/etc/inittab.real" ]; then
        cp "$ROOTMOUNT/etc/inittab.real" "$ROOTMOUNT/etc/inittab"
    fi

    if [ -f "$ROOTMOUNT/etc/inittab" ]; then
        chmod 755 "$ROOTMOUNT/etc/inittab"
        chown root.root "$ROOTMOUNT/etc/inittab"
    fi
    if [ -f "$ROOTMOUNT/sbin/unconfigured.sh" ]; then
        chmod 755 "$ROOTMOUNT/sbin/unconfigured.sh"
        chown root.root "$ROOTMOUNT/sbin/unconfigured.sh"
    fi
}

prepare_base_system_093r6() {
    if [ -f "$ROOTMOUNT/etc/init.d/inittab" ] && [ ! -f "$ROOTMOUNT/etc/inittab" ]; then
        cp "$ROOTMOUNT/etc/init.d/inittab" "$ROOTMOUNT/etc/inittab"
        set_file_mode "$ROOTMOUNT/etc/inittab"
    fi
}

copy_base_configuration_hooks() {
    if [ -n "$DEBIAN_ROOT_TARBALL" ] && [ -f "$DEBIAN_ROOT_TARBALL" ]; then
        mkdir -p "$ROOTMOUNT/root"
        if [ -f "$ROOTMOUNT/root/$DEBIAN_ROOT_HOOK" ] && [ ! -f "$ROOTMOUNT/root/$DEBIAN_ROOT_HOOK.real" ]; then
            mv "$ROOTMOUNT/root/$DEBIAN_ROOT_HOOK" "$ROOTMOUNT/root/$DEBIAN_ROOT_HOOK.real"
        fi
        GZIP_EXTRACT=$(gzip_extract_cmd) || return 1
        (
            cd "$ROOTMOUNT/root" &&
            $GZIP_EXTRACT < "$DEBIAN_ROOT_TARBALL" | extract_tar_stream
        )
        chown -R root.root "$ROOTMOUNT/root"
    elif [ -f /etc/root.sh ]; then
        cp /etc/root.sh "$ROOTMOUNT/root/$DEBIAN_ROOT_HOOK"
        chmod 755 "$ROOTMOUNT/root/$DEBIAN_ROOT_HOOK"
    fi

    if [ -z "$DEBIAN_SKIP_SETUP_SH" ] && [ -f /etc/setup.sh ]; then
        cp /etc/setup.sh $ROOTMOUNT/sbin/setup.sh
        chmod 755 $ROOTMOUNT/sbin/setup.sh
    fi

    rm -f $ROOTMOUNT/sbin/unconfigured.sh
}

extract_base_system() {
    echo "### Installing base system to $ROOTDEV..."
    cd $ROOTMOUNT
    GZIP_EXTRACT=$(gzip_extract_cmd) || return 1
    if [ -n "$DEBIAN_BASE_TARBALL" ]; then
        $GZIP_EXTRACT < "$INSTMOUNT/$DEBIAN_BASE_TARBALL" | extract_tar_stream
    else
        for DISK in $DEBIAN_BASE_DISKS; do
            dd if=$INSTMOUNT/$DISK.img bs=512 skip=1 2>/dev/null
        done | $GZIP_EXTRACT | extract_tar_stream
    fi
    mv $ROOTMOUNT/fstab.tmp $ROOTMOUNT/etc/fstab
}

install_boot_floppy_kernel() {
    if [ -z "$DEBIAN_INSTALL_BOOT_FLOPPY" ]; then
        return 0
    fi

    echo "### Installing boot kernel..."
    if [ -f "$INSTMOUNT/bootflop/install.sh" ]; then
        cd "$INSTMOUNT/bootflop"
        ./install.sh $ROOTMOUNT
        cd $ROOTMOUNT
    else
        mkdir -p /floppy
        mount -o ro -t msdos /dev/fd0 /floppy
        cd /floppy
        if [ -f ./install.sh ]; then
            ./install.sh $ROOTMOUNT
        else
            ./INSTALL.SH $ROOTMOUNT
        fi
        cd $ROOTMOUNT
        umount /floppy
    fi
}

install_driver_modules() {
    if [ -z "$DEBIAN_INSTALL_DRIVERS" ] || [ ! -f "$INSTMOUNT/drivers/install.sh" ]; then
        return 0
    fi

    echo "### Installing driver modules..."
    cd "$INSTMOUNT/drivers"
    sh ./install.sh "$ROOTMOUNT"
    cd "$ROOTMOUNT"
}

configure_driver_modules() {
    if [ -z "$DEBIAN_CONFIGURE_MODULES" ]; then
        return 0
    fi

    if [ -f "$ROOTMOUNT/etc/modules" ]; then
        echo ne >> "$ROOTMOUNT/etc/modules"
    fi

    if [ -f "$ROOTMOUNT/etc/conf.modules" ]; then
        echo 'alias eth0 ne' >> "$ROOTMOUNT/etc/conf.modules"
        echo 'options ne io=0x300 irq=9' >> "$ROOTMOUNT/etc/conf.modules"
    fi

    if [ -f "$ROOTMOUNT/etc/modules" ] && [ ! -f "$ROOTMOUNT/etc/modules.old" ]; then
        cp "$ROOTMOUNT/etc/modules" "$ROOTMOUNT/etc/modules.old"
    fi
}

debian_install_lilo() {
    LILO_OK=

    if [ -n "$DEBIAN_OPTIONAL_LILO" ]; then
        if [ ! -x $ROOTMOUNT/sbin/lilo ] || [ ! -x $ROOTMOUNT/sbin/activate ] || [ ! -f $ROOTMOUNT/boot/mbr.b ]; then
            return 0
        fi
    fi

    echo "### Installing LILO for $ROOTDEV..."
    cat > $ROOTMOUNT/etc/lilo.conf <<EOF
boot=$ROOTDEV
root=$ROOTDEV
compact
install=/boot/boot.b
map=/boot/map
vga=normal
delay=20
image=/vmlinuz
label=Linux
read-only
EOF
    chmod 644 $ROOTMOUNT/etc/lilo.conf
    if (export LD_LIBRARY_PATH="$ROOTMOUNT/lib:$ROOTMOUNT/usr/lib"; \
      $ROOTMOUNT/sbin/lilo -r $ROOTMOUNT >/dev/null 2>&1); then
        LILO_OK=1
    elif [ -x /sbin/lilo ]; then
        if /sbin/lilo -r $ROOTMOUNT -C /etc/lilo.conf >/dev/null 2>&1; then
            LILO_OK=1
        fi
    elif [ -x /usr/sbin/lilo ]; then
        if /usr/sbin/lilo -r $ROOTMOUNT -C /etc/lilo.conf >/dev/null 2>&1; then
            LILO_OK=1
        fi
    fi

    if [ -z "$LILO_OK" ]; then
        echo "Warning: LILO install failed for $ROOTDEV. Use the rescue floppy to boot."
        return 0
    fi

    echo "### Installing MBR..."
    BOOTDEV=$(echo $ROOTDEV | sed -e 's/[0-9]$//')
    cp $ROOTMOUNT/boot/mbr.b $BOOTDEV

    echo "### Setting active partition..."
    BOOTPART=$(echo $ROOTDEV | sed -e 's/^[^0-9]*//')
    if (export LD_LIBRARY_PATH="$ROOTMOUNT/lib:$ROOTMOUNT/usr/lib"; \
      $ROOTMOUNT/sbin/activate $BOOTDEV $BOOTPART >/dev/null 2>&1); then
        return 0
    elif [ -x /sbin/activate ]; then
        /sbin/activate $BOOTDEV $BOOTPART >/dev/null 2>&1
    elif [ -x /usr/sbin/activate ]; then
        /usr/sbin/activate $BOOTDEV $BOOTPART >/dev/null 2>&1
    fi
}

debian_install_base_dinstall() {
    set_debian_baseinst_path
    extract_base_system

    if [ -n "$DEBIAN_PREPARE_FUNCTION" ]; then
        echo "### Configuring base system..."
        $DEBIAN_PREPARE_FUNCTION
    fi

    install_boot_floppy_kernel
    install_driver_modules
    configure_driver_modules

    echo "### Configuring base system..."
    copy_base_configuration_hooks

    debian_install_lilo
}

debian_install_base_091_style() {
  # unpack the base system
  echo "### Installing base system to $ROOTDEV..."
  cd $ROOTMOUNT
  zcat < $INSTMOUNT/basedsk1.img 2>/dev/null | cpio -dimV
  zcat < $INSTMOUNT/basedsk2.img 2>/dev/null | cpio -dimV
  mv $ROOTMOUNT/fstab.tmp $ROOTMOUNT/etc/fstab

  # change root device in rc scripts
  echo "### Configuring init scripts for $ROOTDEV..."
  cat $ROOTMOUNT/etc/rc.d/rc.S | 
    sed "s|/dev/hda3|$ROOTDEV|g" > $ROOTMOUNT/tmp/rc.S
  chmod 754 $ROOTMOUNT/etc/rc.d/rc.S
  mv $ROOTMOUNT/tmp/rc.S $ROOTMOUNT/etc/rc.d/rc.S
  cat $ROOTMOUNT/etc/rc.d/rc.K | 
    sed "s|/dev/hda3|$ROOTDEV|g" > $ROOTMOUNT/tmp/rc.K
  mv $ROOTMOUNT/tmp/rc.K $ROOTMOUNT/etc/rc.d/rc.K
  chmod 754 $ROOTMOUNT/etc/rc.d/rc.S

  echo "### Configuring lilo for $ROOTDEV..."
  # set root device, read only, and normal vga in kernel
  $ROOTMOUNT/usr/sbin/rdev $ROOTMOUNT/vmlinuz $ROOTDEV
  $ROOTMOUNT/usr/sbin/rdev -R $ROOTMOUNT/vmlinuz 1
  $ROOTMOUNT/usr/sbin/rdev -v $ROOTMOUNT/vmlinuz -1

  # change root device in lilo.conf, then install
  cat $ROOTMOUNT/etc/lilo.conf | 
    sed "s|/dev/hda3|$ROOTDEV|g" |
    sed "s|read-only|#read-only|g" |
    sed "s|delay=20|#delay=20|g" > $ROOTMOUNT/tmp/lilo.conf
  mv $ROOTMOUNT/tmp/lilo.conf $ROOTMOUNT/etc/lilo.conf
  $ROOTMOUNT/sbin/lilo -r $ROOTMOUNT -C /etc/lilo.conf

  # copy configuration script to new filesystem
  $ROOTMOUNT/bin/cp $INSTMOUNT/autoinst.d/autoconf.sh $ROOTMOUNT/sbin/setup.sh
  chmod 755 $ROOTMOUNT/sbin/setup.sh
}

debian_install_base() {
  DEBIAN_BASE_STYLE=${DEBIAN_BASE_STYLE:-dinstall}

  case $DEBIAN_BASE_STYLE in
    091 )
      DEBIAN_BASE_DISKS=${DEBIAN_BASE_DISKS:-"basedsk1 basedsk2 basedsk3"}
      debian_install_base_091_style
      ;;
    dinstall )
      DEBIAN_PREPARE_FUNCTION=${DEBIAN_PREPARE_FUNCTION:-prepare_base_system_dinstall}
      DEBIAN_ROOT_HOOK=${DEBIAN_ROOT_HOOK:-.configure}
      DEBIAN_INSTALL_BOOT_FLOPPY=${DEBIAN_INSTALL_BOOT_FLOPPY:-1}
      DEBIAN_CONFIGURE_MODULES=${DEBIAN_CONFIGURE_MODULES:-1}
      DEBIAN_GUARD_ETH0=${DEBIAN_GUARD_ETH0:-1}
      debian_install_base_dinstall
      ;;
    * )
      echo "Unknown Debian base install style: $DEBIAN_BASE_STYLE"
      exit 1
      ;;
  esac
}
