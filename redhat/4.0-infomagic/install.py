from retro_host.install.drivers.redhat import CInstaller, CInstallerOptions


def install(session):
    installer = CInstaller(
        session,
        CInstallerOptions(
            boot_prompt="LILO boot:", flow="4x", x_card_down=24, keyboard_late=True
        ),
    )
    installer.start()
    installer.partition_4x()
    installer.components_40()
    installer.finish_components()
    installer.x11_4x()
    installer.network()
    installer.finish()
