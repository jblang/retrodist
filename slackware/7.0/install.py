from retro_host.install.drivers.slackware import PkgtoolOptions, boot_pkgtool

def install(session):
    boot_pkgtool(session, options=PkgtoolOptions(xwmconfig=True))
