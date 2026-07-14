from retro_host.install.drivers.redhat import CInstaller, CInstallerOptions


def install(session):
    installer = CInstaller(
        session,
        CInstallerOptions(
            flow="4x", x_card_down=66, keyboard_after_packages=True, lilo_extra_f12=1
        ),
    )
    installer.start()
    installer.partition_4x()
    installer.components_40()
    installer.finish_components()
    installer.x11_4x()
    installer.network()
    installer.finish()
