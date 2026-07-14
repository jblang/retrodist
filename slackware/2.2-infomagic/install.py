from retro_host.install.drivers.slackware import PkgtoolOptions, boot_pkgtool


def install(session):
    boot_pkgtool(
        session,
        root_prompt="VFS: Insert ramdisk floppy and press ENTER",
        options=PkgtoolOptions(source="/dev/hdb1"),
    )
