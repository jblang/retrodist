from retro_host.install import Match
from retro_host.install.drivers.debian import Dinstall, DinstallOptions


def install(session):
    session.vga_wait("boot:", match=Match.LINE)
    session.kb_type("", enter=True)
    session.vga_wait(
        "VFS: Insert root floppy disk to be loaded into ramdisk and press ENTER",
        match=Match.LINE,
    )
    session.change_floppy("root.img")
    session.kb_press("ret")
    Dinstall(
        session,
        DinstallOptions(
            hostname="buzz",
            keymap="",
            configure_keyboard=True,
            kernel_floppy="boot.img",
            driver_floppy=None,
            relogin=True,
            net_module="ne",
            net_module_args="io=0x300 irq=9",
        ),
    ).install()
