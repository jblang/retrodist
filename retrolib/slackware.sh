# Slackware-specific install media and tagfile preparation helpers.
slackware_build_tagfiles() {
  local PKGROOT
  PKGROOT=$(slackware_staged_pkg_root) || return

  find "$PKGROOT" -mindepth 1 -maxdepth 1 -type d | while read -r SERIESDIR; do
    basename "$SERIESDIR" | sed 's/[0-9][0-9]*$//'
  done | sort -u | while read -r SERIES; do
    if [[ -z "$SERIES" ]]; then
      continue
    fi
    local FIRSTDIR
    local SERIESPKG=$TEMPDIR/$SERIES.pkgs
    FIRSTDIR=$(find "$PKGROOT" -mindepth 1 -maxdepth 1 -type d -name "${SERIES}[0-9]*" | sort | head -n 1)
    if [[ -z "$FIRSTDIR" ]]; then
      continue
    fi
    find "$PKGROOT" -mindepth 1 -maxdepth 1 -type d -name "${SERIES}[0-9]*" | while read -r SERIESDIR; do
      find "$SERIESDIR" -maxdepth 1 -type f \( -name '*.tgz' -o -name '*.tar' \)
    done | while read -r TGZ; do
      basename "$TGZ" | sed 's/\.tgz$//' | sed 's/\.tar$//' | awk -F- '{
        if (NF > 3) {
          for (i = 1; i <= NF - 3; i++) {
            printf "%s%s", $i, (i < NF - 3 ? "-" : ORS)
          }
        } else {
          print $0
        }
      }'
    done | sort -u > "$SERIESPKG"
    cat "$SERIESPKG" | while read -r PKG; do
      if [[ -n "$PKG" ]]; then
        printf "%s:     ADD\n" "$PKG"
      fi
    done > "$FIRSTDIR/tagfile"
    cp "$FIRSTDIR/tagfile" "$FIRSTDIR/tagfile.new"
  done
}

slackware_staged_pkg_root() {
  local ROOT
  for ROOT in install/slakware install/slackware install; do
    if [[ -d "$ROOT" ]] && find "$ROOT" -mindepth 2 -maxdepth 2 -type f \( -name '*.tgz' -o -name '*.tar' \) 2>/dev/null | grep -q .; then
      printf '%s\n' "$ROOT"
      return 0
    fi
  done
  return 1
}

slackware_iso_tag_root() {
  local ISO=$1
  local ROOT
  for ROOT in slakware slackware; do
    if 7z l "$ISO" "$ROOT/**/*.tgz" 2>/dev/null | grep -q '\.tgz$'; then
      printf '%s\n' "$ROOT"
      return 0
    fi
    if 7z l "$ISO" "$ROOT/**/*.tar" 2>/dev/null | grep -q '\.tar$'; then
      printf '%s\n' "$ROOT"
      return 0
    fi
  done
  return 1
}

slackware_build_tagfiles_from_iso() {
  local ISO=$1
  local PATHROOT=$2
  local TAGROOT=install/tagfiles
  local PKGLIST=$TEMPDIR/slackware-iso-pkgs.txt

  rm -rf "$TAGROOT"
  mkdir -p "$TAGROOT"
  : > "$PKGLIST"

  7z l "$ISO" "$PATHROOT/**/*.tgz" | awk '/^[0-9]{4}-[0-9]{2}-[0-9]{2} / { print $6 }' >> "$PKGLIST"
  7z l "$ISO" "$PATHROOT/**/*.tar" | awk '/^[0-9]{4}-[0-9]{2}-[0-9]{2} / { print $6 }' >> "$PKGLIST"
  sort -u "$PKGLIST" -o "$PKGLIST"

  awk -F/ 'NF >= 3 { print $2 }' "$PKGLIST" | sort -u | while read -r DISKDIR; do
    local TAGDIR
    [ -n "$DISKDIR" ] || continue
    TAGDIR="$TAGROOT/$DISKDIR"
    mkdir -p "$TAGDIR"
    awk -F/ -v disk="$DISKDIR" '
      $2 == disk {
        pkg = $3
        sub(/\.tgz$/, "", pkg)
        sub(/\.tar$/, "", pkg)
        n = split(pkg, parts, /-/)
        if (n > 3) {
          out = parts[1]
          for (i = 2; i <= n - 3; i++) {
            out = out "-" parts[i]
          }
          print out ":     ADD"
        } else {
          print pkg ":     ADD"
        }
      }
    ' "$PKGLIST" | sort -u > "$TAGDIR/tagfile"
  done
}

slackware_set_tagfile_package() {
  local PKG=$1
  local STATE=$2
  find install \( -name tagfile -o -name 'tagfile.new' \) -type f | while read -r TAGFILE; do
    if grep -q "^$PKG:" "$TAGFILE"; then
      sed -i '' -E "s/^($PKG:)[[:space:]]*(ADD|REC|OPT|SKP)$/\\1     $STATE/" "$TAGFILE"
    fi
  done
}

slackware_apply_pkgskip() {
  local PKGSKIP=$CONFDIR/pkgskip.txt
  if [[ ! -f "$PKGSKIP" ]]; then
    return
  fi
  cat_newline "$PKGSKIP" | while read -r PKG _; do
    case "$PKG" in
      "" | \#*) continue ;;
    esac
    slackware_set_tagfile_package "$PKG" SKP
  done
}

slackware_prepare_tagfiles() {
  local SOURCE_ISO="${QEMU_CDROM:-disc1.iso}"

  if slackware_staged_pkg_root >/dev/null; then
    slackware_build_tagfiles
  elif [[ -f "$ORIGDIR/$SOURCE_ISO" ]]; then
    local TAGROOT
    TAGROOT=$(slackware_iso_tag_root "$ORIGDIR/$SOURCE_ISO") || return
    slackware_build_tagfiles_from_iso "$ORIGDIR/$SOURCE_ISO" "$TAGROOT"
  else
    return
  fi

  for PKG in idekern idenet x_svga x311svga; do
    slackware_set_tagfile_package "$PKG" ADD
  done

  slackware_apply_pkgskip

  sync
}
