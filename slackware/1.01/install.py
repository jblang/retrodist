from retro_host.install.drivers.slackware_early import Sysinstall


def install(session):
    Sysinstall(session).install()
