script_import ../dialog-setup.sh

screen_wait -l "Please remove the boot kernel disk from your floppy drive,"
script_change_floppy root.img
kb_press_key ret
screen_wait "VFS: Insert root floppy and press ENTER"
kb_press_key ret

SETUP_HOSTNAME=darkstar
SETUP_SOURCE=$FAT_PARTITION
# 1.1.2 has no Path prompting mode; use the tagfiles staged in the package tree.
PROMPT_MODE=Normal

# 1.1.2's setup chains SOURCE before TARGET.
dialog_target_source() {
    dialog_select_source
    dialog_format_root
    dialog_mount_fat
}

# 1.1.2's liloconfig is a single numbered menu, not the Begin/Linux/Install
# sequence later versions use.
dialog_install_lilo() {
    dialog_answer "$1" menu 2 # Install LILO to Master Boot Record
}

dialog_setup
