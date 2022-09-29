# Debian 0.91

Debian 0.91, released in January 1994, was the first public beta and oldest surviving release of Debian. The `.deb` package format at this time was simply a gzipped CPIO archive, and was not compatible with the package format used in newer versions.

### Automatic Installation

To automatically install 0.91, ignore the onscreen instructions and do the following instead:

- Type `/autoinst.sh` at the shell prompt.
- The script will automatically partition and format your drive, install the base system, and set up lilo to boot from the hard drive.
- Once the VM reboots, the scripts continue to install all the additional packages and configure your system.
- The VM will reboot once again and you have a fully loaded Debian 0.91 system with properly configured X, networking, and a serial console.

### Manual Installation

Seriously, just use the automatic installer, but if you *must* have the authentic installation experience, pay careful attention:

- Run `dinstall` at the shell prompt and follow the onscreen steps: 

1. Partition the hard drive
2. Initialize swap
3. Format the Linux root partition
4. View the partition table (optional)
5. Install the base system  

- Choose `/dev/fd0` for the drive to install from.
- When prompted to insert the base disks, type `Ctrl-A`, then `c` in the terminal where you ran `retro` (not the QEMU window) to access the QEMU monitor.
- At the `(qemu)` prompt, enter the command to insert the first disk:

    ```
    change floppy0 ../.cache/install/basedsk1.img
    ```

- Switch back to QEMU and press enter to install disk 1.
- When prompted to insert disk 2 switch to the monitor and enter:

    ```
    change floppy0 ../.cache/install/basedsk2.img
    ```

- Switch back to QEMU and press enter to install disk 2.
- Answer the configuration questions. Refer to the [config.sh](config.sh) file for network configuration.
- Answer `n` when prompted to create a boot disk. Otherwise you will overwrite the install disk.
- At the menu, choose 7. Return to shell (don't reboot). 
- Type `/root/usr/bin/vi /root/etc/lilo.conf`
- Change `root=/dev/hda3` to `root=/dev/hda2` (or your root partition).
- Save the file and exit vi.
- Run `/root/sbin/lilo -r /root -C /etc/lilo.conf`. You should see `Added linux` if successful.
- Type `reboot` to reboot into the base system.
- Log in as `root` and run `dpkg` to install additional packages (follow onscreen instructions).