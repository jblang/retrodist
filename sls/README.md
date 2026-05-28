# Softlanding Linux System

[Softlanding Linux System (SLS)](https://en.wikipedia.org/wiki/Softlanding_Linux_System) was one of the first Linux distributions. The first release was by Peter MacDonald[4] in May 1992.

## Installation

1. Boot the VM normally.
2. When prompted `Press <RETURN> to see SVGA-modes available or <SPACE> to continue.`, press either.
   - `<RETURN>` will go to 80x50 mode
   - `<SPACE>` will stay in 80x25 mode
3. When prompted `Enter Drive You Will Be Doing The Installation From (1/2/3/4)`, press `C-a c` in the terminal running qemu and to enter the QEMU monitor, then type:
  ```text
  change floppy0 root.img
  ```
4. Enter `1` at the prompt. Ignore the stock installer prompts and run the staged autoinstall script from the DOS partition:

    ```sh
    mkdir /retro
    mount -t msdos /dev/hdb1 /retro
    sh /retro/autoinst
    ```
6. When prompted `Reattach boot.img and press Ctrl-Alt-Del in the VM to reboot`, enter the following in the QEMU monitor:
  ```text
  change floppy0 boot.img
  ```
7. Press `Ctrl-Alt-Del` in the QEMU window (with input captured) to reboot the VM.
8. Repeat steps 2-5.
9. You'll be prompted a few times about a file that already exists asking if you wish to overwrite it.  Enter `y` for both.
10. When prompted `Reattach boot.img and press ENTER.`, repeat step 6.

After the boot disk is written, the VM will reboot into the installed system.