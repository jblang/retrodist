from retro_host.install.drivers.redhat import CInstaller, CInstallerOptions


def install(session):
    installer = CInstaller(
        session,
        CInstallerOptions(
            keyboard_early=True,
            cdrom_type_prompt=False,
            flow="42",
            monitor_key="f12",
            timezone_prompt="Configure Timezones",
            lilo_extra_f12=1,
        ),
    )
    installer.start()
    installer.partition_4x()
    session.vga_wait("Components to Install")
    session.kb_press("spc")
    session.kb_repeat("down", 2)
    session.kb_press("spc", "down", "spc", "down", "spc")
    session.kb_repeat("down", 9)
    for _ in range(4):
        session.kb_press("spc", "down")
    session.kb_press("spc")
    session.kb_repeat("down", 7)
    session.kb_press("spc", "f12")
    installer.finish_components()
    installer.x11_4x()
    installer.network()
    installer.finish()
