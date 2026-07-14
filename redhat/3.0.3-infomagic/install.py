from retro_host.install.drivers.redhat_early import PerlInstaller, PerlInstallerOptions


def install(session):
    i = PerlInstaller(session, PerlInstallerOptions(boot_command="linux root=/dev/hdc"))
    i.boot()
    i.step("This script will walk you through each step of the installation.", "ret")
    i.step("Color Screen", "ret")
    i.step("Text based install", "ret")
    i.partition("Disk Partitions")
    i.step("Do you want to use this as a swap partition?", "y")
    session.vga_wait("Do you want to configure ethernet TCP/IP networking")
    i.configure_network()
    i.format_root()
    i.step("Select each series that you want to install.", "ret")
    i.step("Which X server would you like to use?", "s", "ret")
    i.step("Would you like to select and unselect individual packages", "n")
    i.step("Package Installation is complete.", "ret")
    i.finish("How does your system clock store the time?")
