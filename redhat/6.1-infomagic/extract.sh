extract_link_install_iso "$DOWNLOAD_D/disc1.iso"
if ! command -v xorriso >/dev/null 2>&1; then
    log_error "xorriso is required to extract boot.img from install.iso. Run retro prereq to install it."
    return 1
fi
log_info "Extracting Red Hat 6.1 boot.img from install.iso with xorriso"
xorriso -indev "$DOWNLOAD_D/disc1.iso" -osirrox on -extract /images/boot.img boot.img
