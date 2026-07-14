from retro_host.install.drivers.redhat import CInstaller, CInstallerOptions


def install(session):
    installer = CInstaller(
        session,
        CInstallerOptions(
            keyboard_early=True,
            pcmcia_prompt=False,
            cdrom_type_prompt=False,
            insert_cd_prompt="Insert your Red Hat CD",
            flow="50",
            timezone_prompt="Configure Timezones",
            lilo_extra_f12=1,
        ),
    )
    installer.start()
    session.vga_wait("Which tool would you like to use?")
    session.kb_press("tab", "ret")
    session.vga_wait("Partition Disks")
    installer.partition_helper()
    installer.step("Partition Disks", "ret")
    installer.step("Select Root Partition", "ret")
    installer.step("Partition Disk", "f12")
    installer.step("Active Swap Space", "f12")
    installer.step("Format Partitions", "spc", "f12")
    installer.components_default()
    installer.finish_components()
    installer.step("Probing found a PS/2 mouse", "f12")
    installer.step("Emulate Three Buttons", "f12")
    installer.x11_5x()
    installer.network()
    installer.finish()
