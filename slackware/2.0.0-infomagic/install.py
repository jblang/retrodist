from retro_host.install.drivers.slackware import PkgtoolOptions, boot_pkgtool

def install(session):
    boot_pkgtool(session, root_prompt="Please remove the boot kernel disk from your floppy drive, insert a", options=PkgtoolOptions(source="/dev/hdb1"))
