# shellcheck shell=bash
# Slackware-specific install media and tagfile preparation helpers.

# Builds default ADD tagfiles from staged Slackware package directories.
slackware_build_tagfiles() {
  local pkgroot firstdir seriespkg seriesdir series tgz pkg
  pkgroot=$(slackware_staged_pkg_root) || return

  find "$pkgroot" -mindepth 1 -maxdepth 1 -type d | while IFS= read -r seriesdir; do
    basename "$seriesdir" | sed 's/[0-9][0-9]*$//'
  done | sort -u | while IFS= read -r SERIES; do
    series=$SERIES
    if [[ -z "$series" ]]; then
      continue
    fi
    seriespkg=$TEMPDIR/$series.pkgs
    firstdir=$(find "$pkgroot" -mindepth 1 -maxdepth 1 -type d -name "${series}[0-9]*" | sort | head -n 1)
    if [[ -z "$firstdir" ]]; then
      continue
    fi
    find "$pkgroot" -mindepth 1 -maxdepth 1 -type d -name "${series}[0-9]*" | while IFS= read -r seriesdir; do
      find "$seriesdir" -maxdepth 1 -type f \( -name '*.tgz' -o -name '*.tar' \)
    done | while IFS= read -r tgz; do
      basename "$tgz" | sed 's/\.tgz$//' | sed 's/\.tar$//' | awk -F- '{
        if (NF > 3) {
          for (i = 1; i <= NF - 3; i++) {
            printf "%s%s", $i, (i < NF - 3 ? "-" : ORS)
          }
        } else {
          print $0
        }
      }'
    done | sort -u > "$seriespkg"
    while IFS= read -r pkg; do
      if [[ -n "$pkg" ]]; then
        printf "%s:     ADD\n" "$pkg"
      fi
    done < "$seriespkg" > "$firstdir/tagfile"
    cp "$firstdir/tagfile" "$firstdir/tagfile.new"
  done
}

# Finds the staged Slackware package root on FAT media.
slackware_staged_pkg_root() {
  local root
  for root in fat/packages fat; do
    if [[ -d "$root" ]] && find "$root" -mindepth 2 -maxdepth 2 -type f \( -name '*.tgz' -o -name '*.tar' \) 2>/dev/null | grep -q .; then
      printf '%s\n' "$root"
      return 0
    fi
  done
  return 1
}

# Finds the Slackware package root inside an ISO.
slackware_iso_tag_root() {
  local iso=$1
  local root
  for root in slakware slackware; do
    if 7z l "$iso" "$root/**/*.tgz" 2>/dev/null | grep -q '\.tgz$'; then
      printf '%s\n' "$root"
      return 0
    fi
    if 7z l "$iso" "$root/**/*.tar" 2>/dev/null | grep -q '\.tar$'; then
      printf '%s\n' "$root"
      return 0
    fi
  done
  return 1
}

# Builds tagfiles by reading package names directly from an ISO.
slackware_build_tagfiles_from_iso() {
  local iso=$1
  local pathroot=$2
  local tagroot=fat/tagfiles
  local pkglist=$TEMPDIR/slackware-iso-pkgs.txt
  local diskdir tagdir

  rm -rf "$tagroot"
  mkdir -p "$tagroot"
  : > "$pkglist"

  7z l "$iso" "$pathroot/**/*.tgz" | awk '/^[0-9]{4}-[0-9]{2}-[0-9]{2} / { print $6 }' >> "$pkglist"
  7z l "$iso" "$pathroot/**/*.tar" | awk '/^[0-9]{4}-[0-9]{2}-[0-9]{2} / { print $6 }' >> "$pkglist"
  sort -u "$pkglist" -o "$pkglist"

  awk -F/ 'NF >= 3 { print $2 }' "$pkglist" | sort -u | while IFS= read -r diskdir; do
    [ -n "$diskdir" ] || continue
    tagdir="$tagroot/$diskdir"
    mkdir -p "$tagdir"
    awk -F/ -v disk="$diskdir" '
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
    ' "$pkglist" | sort -u > "$tagdir/tagfile"
  done
}

# Sets one package's state in every staged Slackware tagfile.
slackware_set_tagfile_package() {
  local pkg=$1
  local state=$2
  local tagfile tmpfile
  find fat \( -name tagfile -o -name 'tagfile.new' \) -type f | while IFS= read -r tagfile; do
    if grep -q "^$pkg:" "$tagfile"; then
      tmpfile="$tagfile.tmp.$$"
      awk -v pkg="$pkg" -v state="$state" '
        $1 == pkg ":" && $2 ~ /^(ADD|REC|OPT|SKP)$/ {
          print pkg ":     " state
          next
        }
        { print }
      ' "$tagfile" > "$tmpfile" && mv "$tmpfile" "$tagfile"
    fi
  done
}

# Applies package skip rules from pkgskip.txt.
slackware_apply_pkgskip() {
  local pkgskip
  local pkg
  pkgskip=$(retro_config_file pkgskip.txt) || return
  cat_newline "$pkgskip" | while IFS= read -r pkg _; do
    case "$pkg" in
      "" | \#*) continue ;;
    esac
    slackware_set_tagfile_package "$pkg" SKP
  done
}

# Prepares Slackware tagfiles from staged packages or install ISO contents.
slackware_prepare_tagfiles() {
  local source_iso=install.iso
  local tagroot
  local pkg

  if slackware_staged_pkg_root >/dev/null; then
    slackware_build_tagfiles
  elif [[ -f "$source_iso" ]]; then
    tagroot=$(slackware_iso_tag_root "$source_iso") || return
    slackware_build_tagfiles_from_iso "$source_iso" "$tagroot"
  elif [[ -f "$ORIGDIR/disc1.iso" ]]; then
    tagroot=$(slackware_iso_tag_root "$ORIGDIR/disc1.iso") || return
    slackware_build_tagfiles_from_iso "$ORIGDIR/disc1.iso" "$tagroot"
  else
    return
  fi

  for pkg in idekern idenet x_svga x311svga; do
    slackware_set_tagfile_package "$pkg" ADD
  done

  slackware_apply_pkgskip

  sync
}
