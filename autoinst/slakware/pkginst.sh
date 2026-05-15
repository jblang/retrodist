# installer for pkgtool-based Slackware versions

slackware_pkgtool_install_111() {
  SLACK_ADM_DIR=usr/adm
  SLACK_SPOOL_DIR=usr/spool
  SLACK_TIMECONFIG=$SLACK_ADM_DIR/setup/setup.timeconfig
  SLACK_LILOCONFIG=$SLACK_ADM_DIR/setup/setup.liloconfig
  SLACK_PKGTOOL_SOURCE=/bin/pkgtool
  SLACK_SETUP_SOURCE=/bin/setup

  slackware_install_with_pkgtool
}

slackware_pkgtool_install() {
  SLACK_ADM_DIR=var/adm
  SLACK_SPOOL_DIR=var/spool
  SLACK_TIMECONFIG=$SLACK_ADM_DIR/setup/setup.timeconfig
  SLACK_LILOCONFIG=$SLACK_ADM_DIR/setup/setup.liloconfig
  SLACK_PKGTOOL_SOURCE=/bin/pkgtool.tty
  SLACK_SETUP_SOURCE=/bin/setup.tty

  slackware_install_with_pkgtool
}

normalize_sets() {
  SETS=`echo $SETS | sed 's/[ ;,]/#/g'`
}

setup_state_mkdir() {
  for SETUPDIR in `setup_state_dirs`; do
    if [ ! -d "$SETUPDIR" ]; then
      mkdir -p "$SETUPDIR"
    fi
  done
}

setup_state_dirs() {
  echo /tmp
  echo /var/log/setup/tmp
  if [ -n "$ROOTMOUNT" ]; then
    echo "$ROOTMOUNT/var/log/setup/tmp"
  fi
}

write_setup_state() {
  STATEFILE=$1
  STATEVALUE=$2
  setup_state_mkdir
  for SETUPDIR in `setup_state_dirs`; do
    echo "$STATEVALUE" > "$SETUPDIR/$STATEFILE"
  done
}

remove_setup_state() {
  STATEFILE=$1
  for SETUPDIR in `setup_state_dirs`; do
    rm -f "$SETUPDIR/$STATEFILE"
  done
}

find_cdrom_source_path() {
  for SOURCE in slakware slackware ; do
    if [ -d "$CD_MOUNT/$SOURCE" ]; then
      echo "$CD_MOUNT/$SOURCE"
      return 0
    fi
  done
  return 1
}

find_staged_source_path() {
  for SOURCE in \
    "$INSTMOUNT/slakware" \
    "$INSTMOUNT/slackware"
  do
    if [ -d "$SOURCE" ]; then
      echo "$SOURCE"
      return 0
    fi
  done
  return 1
}

prepare_pkgtool_source() {
  SLACK_PKG_SOURCE=`find_staged_source_path`
  SLACK_PKG_TAG_MODE=custom_ext
  SLACK_PKGTOOL_BIN="$SLACK_PKGTOOL_SOURCE"

  if [ -x /usr/lib/setup/cpkgtool ]; then
    SLACK_PKGTOOL_BIN=/usr/lib/setup/cpkgtool
  elif [ -x /usr/lib/setup/pkgtool ]; then
    SLACK_PKGTOOL_BIN=/usr/lib/setup/pkgtool
  elif [ -x /bin/pkgtool ]; then
    SLACK_PKGTOOL_BIN=/bin/pkgtool
  elif [ -x /bin/pkgtool.tty ]; then
    SLACK_PKGTOOL_BIN=/bin/pkgtool.tty
  fi

  if [ -d "$INSTMOUNT/tagfiles" ]; then
    SLACK_PKG_TAG_MODE=tagpath
    write_setup_state SeTtagpath "$INSTMOUNT/tagfiles"
  fi

  if [ -z "$SLACK_PKG_SOURCE" ]; then
    CD_DEVICE=${CD_DEVICE:-/dev/hdc}
    CD_MOUNT=${CD_MOUNT:-/var/adm/mount}
    mkdir -p "$CD_MOUNT"
    mount -o ro -t iso9660 "$CD_DEVICE" "$CD_MOUNT"
    if [ ! $? = 0 ]; then
      echo "Unable to mount CD-ROM source $CD_DEVICE on $CD_MOUNT."
      exit 1
    fi

    SLACK_PKG_SOURCE=`find_cdrom_source_path`
    if [ -z "$SLACK_PKG_SOURCE" ]; then
      echo "Unable to find Slackware package tree on mounted CD-ROM."
      umount "$CD_MOUNT"
      exit 1
    fi

    SLACK_CD_FSTAB_ENTRY="$CD_DEVICE    /cdrom    iso9660    ro   1   1"
  fi
}

cleanup_pkgtool_source() {
  remove_setup_state SeTtagext
  rm -f /tmp/custom
  if [ -d "$INSTMOUNT/tagfiles" ]; then
    remove_setup_state SeTtagpath
  fi
  if [ "$SLACK_PKG_TAG_MODE" = "tagpath" ] && [ -n "$CD_MOUNT" ]; then
    if mount | fgrep "on $CD_MOUNT " >/dev/null 2>&1; then
      umount "$CD_MOUNT"
    fi
  fi
}

move_setup_hook() {
  if [ -f "$ROOTMOUNT/$1" ]; then
    if [ ! -d "$ROOTMOUNT/$SLACK_ADM_DIR/setup/install" ]; then
      mkdir -p "$ROOTMOUNT/$SLACK_ADM_DIR/setup/install"
    fi
    mv "$ROOTMOUNT/$1" "$ROOTMOUNT/$SLACK_ADM_DIR/setup/install"
  fi
}

install_pkgtool_sets() {
  echo "### installing packages..."
  normalize_sets
  if [ ! -d "$INSTMOUNT/tmp" ]; then
    mkdir -p "$INSTMOUNT/tmp"
  fi
  rm -f "$INSTMOUNT/tmp/tagfile"
  prepare_pkgtool_source
  if [ "$SLACK_PKG_TAG_MODE" = "custom_ext" ]; then
    write_setup_state SeTtagext ".new"
    echo ".new" > /tmp/custom
  fi
  "$SLACK_PKGTOOL_BIN" -source_mounted -source_dir "$SLACK_PKG_SOURCE" -target_dir "$ROOTMOUNT" -sets "#$SETS#"
  cleanup_pkgtool_source
}

write_rootdev() {
  if [ ! -d "$ROOTMOUNT/etc/rc.d" ]; then
    mkdir -p "$ROOTMOUNT/etc/rc.d"
  fi
  if [ ! -r "$ROOTMOUNT/etc/rc.d/ROOTDEV" ]; then
    echo "$ROOTDEV" > "$ROOTMOUNT/etc/rc.d/ROOTDEV"
    chmod 644 "$ROOTMOUNT/etc/rc.d/ROOTDEV"
  fi
}

install_fstab() {
  if [ ! -r "$ROOTMOUNT/etc/fstab" -a -r "$ROOTMOUNT/fstab.tmp" ]; then
    mv "$ROOTMOUNT/fstab.tmp" "$ROOTMOUNT/etc/fstab"
    chmod 644 "$ROOTMOUNT/etc/fstab"
  fi
  if [ -r "$ROOTMOUNT/etc/fstab" ]; then
    if [ -n "$SLACK_CD_FSTAB_ENTRY" ]; then
      fgrep "/cdrom" "$ROOTMOUNT/etc/fstab" >/dev/null 2>&1
      if [ ! $? = 0 ]; then
        mkdir -p "$ROOTMOUNT/cdrom"
        echo "$SLACK_CD_FSTAB_ENTRY" >> "$ROOTMOUNT/etc/fstab"
      fi
    fi
    fgrep "/proc" "$ROOTMOUNT/etc/fstab" >/dev/null 2>&1
    if [ ! $? = 0 ]; then
      echo "none        /proc        proc        defaults" >> "$ROOTMOUNT/etc/fstab"
      echo " " >> "$ROOTMOUNT/etc/fstab"
    fi
  fi
}

install_cdrom_link() {
  if [ -n "$CD_DEVICE" ]; then
    if [ ! -d "$ROOTMOUNT/dev" ]; then
      mkdir -p "$ROOTMOUNT/dev"
    fi
    if [ ! -L "$ROOTMOUNT/dev/cdrom" -a ! -r "$ROOTMOUNT/dev/cdrom" ]; then
      ( cd "$ROOTMOUNT/dev" ; ln -sf "$CD_DEVICE" cdrom )
    fi
  fi
}

fix_permissions() {
  echo "### fixing permissions..."
    ( cd "$ROOTMOUNT" ; chmod 755 ./ )
  if [ -d "$ROOTMOUNT/var" ]; then
    ( cd "$ROOTMOUNT" ; chmod 755 ./var )
  fi
  if [ -d "$ROOTMOUNT/usr/src/linux" ]; then
    chmod 755 "$ROOTMOUNT/usr/src/linux"
  fi
  if [ ! -d "$ROOTMOUNT/proc" ]; then
    mkdir "$ROOTMOUNT/proc"
    chown root.root "$ROOTMOUNT/proc"
  fi
  if [ ! -L "$ROOTMOUNT/lib/cpp" ]; then
    ( cd "$ROOTMOUNT/lib" ; ln -sf /usr/lib/gcc-lib/i486-linux/*.*.*/cpp cpp )
  fi
  if [ ! -d "$ROOTMOUNT/$SLACK_SPOOL_DIR/uucp" ]; then
    mkdir -p "$ROOTMOUNT/$SLACK_SPOOL_DIR/uucp"
  fi
  chown uucp.uucp "$ROOTMOUNT/$SLACK_SPOOL_DIR/uucp"
  chmod 1777 "$ROOTMOUNT/$SLACK_SPOOL_DIR/uucp"
  if [ ! -d "$ROOTMOUNT/$SLACK_SPOOL_DIR/uucppublic" ]; then
    mkdir -p "$ROOTMOUNT/$SLACK_SPOOL_DIR/uucppublic"
  fi
  chown uucp.uucp "$ROOTMOUNT/$SLACK_SPOOL_DIR/uucppublic"
  chmod 1777 "$ROOTMOUNT/$SLACK_SPOOL_DIR/uucppublic"
  chmod 1777 "$ROOTMOUNT/tmp"
  if [ ! -d "$ROOTMOUNT/$SLACK_SPOOL_DIR/mail" ]; then
    mkdir -p "$ROOTMOUNT/$SLACK_SPOOL_DIR/mail"
    chmod 755 "$ROOTMOUNT/$SLACK_SPOOL_DIR"
    chown root.mail "$ROOTMOUNT/$SLACK_SPOOL_DIR/mail"
    chmod 775 "$ROOTMOUNT/$SLACK_SPOOL_DIR/mail"
  fi
}

set_timezone() {
  if [ -n "$TIMEZONE" -a -d "$ROOTMOUNT/usr/lib/zoneinfo" ]; then
    echo "### setting timezone to $TIMEZONE..."
    ( cd "$ROOTMOUNT/usr/lib/zoneinfo" ; ln -sf "$TIMEZONE" localtime )
    move_setup_hook "$SLACK_TIMECONFIG"
  fi
}

slackware_install_lilo() {
  if [ -x "$ROOTMOUNT/sbin/lilo" ]; then
    echo "### installing lilo..."
    if [ -r "$ROOTMOUNT/boot/vmlinuz" ]; then
      LILO_IMAGE=/boot/vmlinuz
    else
      LILO_IMAGE=/vmlinuz
    fi
    BOOTDEV=`echo "$ROOTDEV" | sed 's/[0-9][0-9]*$//'`
    if [ "$BOOTDEV" = "$ROOTDEV" ]; then
      BOOTDEV=/dev/hda
    fi
    if [ -r "$ROOTMOUNT/etc/lilo.conf" ]; then
      mv "$ROOTMOUNT/etc/lilo.conf" "$ROOTMOUNT/etc/lilo.conf.bak"
    fi
    cat > "$ROOTMOUNT/etc/lilo.conf" << EOF
# LILO configuration file
# generated by autoinst
#
# Start LILO global section
boot = $BOOTDEV
#compact        # faster, but won't work on all systems.
# delay = 5
vga = normal    # force sane state
ramdisk = 0     # paranoia setting
# End LILO global section
# Linux bootable partition config begins
image = $LILO_IMAGE
  root = $ROOTDEV
  label = Linux
  read-only
# Linux bootable partition config ends
EOF
    chmod 644 "$ROOTMOUNT/etc/lilo.conf"
    if [ -x "$ROOTMOUNT/usr/lib/setup/bin/lilo" ]; then
      # On slackware ELF distributions, /sbin/lilo is not usable from the installation
      # environment, so we have to use a.out the version in /usr/lib/setup/bin instead
      "$ROOTMOUNT/usr/lib/setup/bin/lilo" -r "$ROOTMOUNT" -m /boot/map -C /etc/lilo.conf
    elif [ -x "$ROOTMOUNT/sbin/lilo" ]; then
      "$ROOTMOUNT/sbin/lilo" -r "$ROOTMOUNT" -m /boot/map -C /etc/lilo.conf
    else
      echo "Warning: could not find lilo binary. System may be unbootable!"
    fi
    move_setup_hook "$SLACK_LILOCONFIG"
  fi
}

install_autoconf_hook() {
  if [ ! -d "$ROOTMOUNT/etc/rc.d" ]; then
    mkdir -p "$ROOTMOUNT/etc/rc.d"
  fi
  if [ ! -f "$ROOTMOUNT/etc/rc.d/rc.local" ]; then
    touch "$ROOTMOUNT/etc/rc.d/rc.local"
    chmod 644 "$ROOTMOUNT/etc/rc.d/rc.local"
  fi
  cp "$INSTMOUNT/autoinst.d/autoconf.sh" "$ROOTMOUNT/autoconf.sh"
  chmod +x "$ROOTMOUNT/autoconf.sh"
  echo "if [ -x /autoconf.sh ]; then" >> "$ROOTMOUNT/etc/rc.d/rc.local"
  echo "  /autoconf.sh" >> "$ROOTMOUNT/etc/rc.d/rc.local"
  echo "fi" >> "$ROOTMOUNT/etc/rc.d/rc.local"
}

slackware_install_with_pkgtool() {
  install_pkgtool_sets
  write_rootdev
  install_fstab
  install_cdrom_link
  fix_permissions
  set_timezone
  slackware_install_lilo
  install_autoconf_hook
}
