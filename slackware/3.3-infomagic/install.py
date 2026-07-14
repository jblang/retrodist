from retro_host.install.drivers.slackware import boot_pkgtool

def install(session):
    boot_pkgtool(session, root_prompt="VFS: Insert root floppy disk to be loaded into ramdisk and press ENTER")
