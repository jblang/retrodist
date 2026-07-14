from retro_host.install.drivers.redhat_early import PerlInstaller


def install(session):
    installer = PerlInstaller(session)
    installer.boot()
    installer.load_ramdisk("rootdisk.img")
    installer.step("Welcome to the Red Hat Commercial Linux installation program!", "ret")
    installer.step("Important Copyright Notice", "ret")
    installer.insert_boot_disk()
