from retro_host.install import Match
from retro_host.install.drivers.debian import Dinstall, DinstallOptions


def install(session):
    session.vga_wait("boot:", match=Match.LINE)
    session.kb_type("", enter=True)
    Dinstall(session, DinstallOptions(hostname="rex")).install()
