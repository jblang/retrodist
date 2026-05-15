# shellcheck shell=bash
# Extraction helpers for mounting media images and building the staged install tree.
retro_extract() {
  if [[ ! -d $EXTRACTDIR ]]; then
    retro_download
    if [[ -f "$CONFDIR/extract.sh" || -f "$CONFDIR/autoinst.sh" ]]; then
      mkdir -p "$EXTRACTDIR"
      pushd "$EXTRACTDIR" > /dev/null || return
      if [[ -f "$CONFDIR/extract.sh" ]]; then
        # shellcheck source=/dev/null
        source "$CONFDIR/extract.sh"
      fi
      if [[ -f "$CONFDIR/autoinst.sh" ]]; then
        mkdir -p "$EXTRACTDIR/install"
        load_qemu_config
        autoinst_prep
      fi
      popd > /dev/null || return
    else
      echo "Nothing to extract"
    fi
  else
    echo "Using extracted files"
  fi
}
