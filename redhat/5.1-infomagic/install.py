from retro_host.install.drivers.redhat import CInstaller, CInstallerOptions


def install(session):
    installer = CInstaller(
        session,
        CInstallerOptions(
            boot_sleep=1,
            color_prompt=False,
            language_prompt=True,
            keyboard_early=True,
            pcmcia_prompt=False,
            cdrom_type_prompt=False,
            insert_cd_prompt="Insert your Red Hat CD",
            flow="51",
            timezone_prompt="Configure Timezones",
            lilo_extra_f12=1,
            bootdisk_prompt=True,
        ),
    )
    installer.start()
    session.vga_wait("Disk Setup")
    session.kb_press("tab", "ret")
    session.vga_wait("Partition Disks")
    installer.partition_helper()
    installer.step("Partition Disks", "ret")
    installer.step("Current Disk Partitions", "down", "ret")
    session.kb_type("/", enter=True)
    session.kb_press("f12")
    installer.step("Active Swap Space", "f12")
    installer.step("Partitions To Format", "spc", "f12")
    installer.components_default()
    installer.finish_components()
    installer.step("Probing found a PS/2 mouse", "f12")
    installer.step("Configure Mouse", "f12")
    installer.x11_5x()
    installer.network()
    installer.finish()
