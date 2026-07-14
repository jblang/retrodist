from retro_host.install import InstallSession, Match
from retro_host.install.drivers.slackware import Pkgtool, PkgtoolOptions


def install(session: InstallSession) -> None:
    session.vga_wait("boot:", match=Match.LINE)
    session.kb_type("", enter=True)
    session.vga_wait(
        "VFS: Insert ramdisk floppy and press ENTER", match=Match.LINE
    )
    session.change_floppy("root.img")
    session.kb_press("ret")
    Pkgtool(session, PkgtoolOptions(install_mode="VERBOSE")).install()
