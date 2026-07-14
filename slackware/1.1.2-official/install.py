from retro_host.install import Match
from retro_host.install.drivers.slackware import Pkgtool, PkgtoolOptions


def install(session):
    session.vga_wait("Please remove the boot kernel disk from your floppy drive,", match=Match.LINE)
    session.change_floppy("root.img")
    session.kb_press("ret")
    session.vga_wait("VFS: Insert root floppy and press ENTER")
    session.kb_press("ret")
    Pkgtool(
        session,
        PkgtoolOptions(
            setup_hostname="darkstar",
            source="/dev/hdb1",
            tagfile_path=None,
            source_before_target=True,
            simple_lilo=True,
        ),
    ).install()
