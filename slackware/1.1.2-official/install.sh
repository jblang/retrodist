script_import ../pkgtool.sh

vga_wait -l "Please remove the boot kernel disk from your floppy drive,"
script_change_floppy root.img
kb_press ret
vga_wait "VFS: Insert root floppy and press ENTER"
kb_press ret

SETUP_HOSTNAME=darkstar
SETUP_SOURCE=$FAT_PARTITION
# 1.1.2 has no Path prompting mode; use tagfiles staged in the package tree.
TAGFILE_PATH=

# 1.1.2's setup chains SOURCE before TARGET.
pkgtool_target_source() {
    pkgtool_select_source
    pkgtool_format_root
    pkgtool_mount_fat
}

# 1.1.2's liloconfig is a single numbered menu, not the Begin/Linux/Install
# sequence later versions use.
pkgtool_install_lilo() {
    dialog_answer menu "$1" 2 # Install LILO to Master Boot Record
}

pkgtool_setup
