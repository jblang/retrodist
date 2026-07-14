from retro_host.install import Match
from retro_host.install.fdisk import Fdisk


def install(session):
    prompt = session.serial.prompt
    session.vga_wait("boot:", match=Match.LINE)
    session.kb_type("", enter=True)
    session.vga_wait("#", match=Match.LINE)
    session.serial_shell_start()
    session.serial_shell_send(
        "for p in /bin/tput /usr/bin/tput /usr/local/bin/tput; do if [ -f $p ]; then mv $p $p.real; echo exit 0 >$p; chmod 755 $p; fi; done"
    )
    Fdisk(session).partition()
    session.serial.wait("#", line=True)
    session.serial_console_echo("Starting Debian setup; base installation may take a while...")
    session.serial_shell_send("dinstall", wait=False)

    def ask(*questions, answer, regex=False):
        prompt(*questions, answer=answer, regex=regex)

    ask("Please select one:", answer="2")
    ask(r"What is the name of your swap partition", answer="hda1", regex=True)
    ask("Would you like to check for bad blocks (y/n) [y]?", answer="n")
    ask("Press <RETURN> to continue...", answer="")
    ask("Please select one:", answer="3")
    ask("On which partition do you wish to create an ext2 filesystem?", answer="hda2")
    ask("Would you like to check for bad blocks (y/n) [y]?", answer="n")
    ask("Press <RETURN> to continue...", answer="")
    ask("Please select one:", answer="5")
    ask("Continue with the installation of the base system (y/n) [y]?", answer="y")
    ask("or (c)ontinue with the installation:", answer="m")
    ask("Mount which filesystem (ex: /dev/hda3)? /dev/", answer="hda2")
    ask("Mount /dev/hda2 on which directory (ex: /usr)? /root/", answer="")
    ask("or (c)ontinue with the installation:", answer="c")
    ask("Please specify /dev/fd0 or /dev/fd1 [/dev/fd0]: /dev/", answer="")
    session.serial.wait("Please insert basedisk #1 into /dev/fd0 and press <RETURN>:", line=True)
    session.change_floppy("basedsk1")
    session.serial.send("")
    session.serial.wait("Please insert basedisk #2 into /dev/fd0 and press <RETURN>:", line=True)
    session.change_floppy("basedsk2")
    session.serial.send("")
    answers = (
        ("Which partition contains your root filesystem? /dev/", "hda2", False),
        (
            "Which partition is your swap partition (<RETURN> for none)? /dev/",
            "hda1",
            False,
        ),
        ("What is the unqualified hostname of your machine?", "debra", False),
        (r"What is the local domainname", "retro.net", True),
        (r"Your fully-qualified hostname is .* Correct \(y/n\)\?", "y", True),
        ("Does your machine require additional networking setup (y/n)?", "y", False),
        ("What is the IP address of your machine?", "10.0.2.15", False),
        ("What is your netmask?", "255.255.255.0", False),
        ("What is your network address?", "10.0.2.0", False),
        (r"What is your broadcast address", "10.0.2.255", True),
        ("What is your gateway address?", "10.0.2.2", False),
        (r"What is the address of your nameserver", "10.0.2.3", True),
        ("Is this correct (y/n)?", "y", False),
        ("Do you have an ethernet connection (y/n)?", "y", False),
        ("Is your system clock set to GMT?", "y", False),
        (r"Press <RETURN> for more", "", True),
        ("Which timezone?", "US/Central", False),
        ("Load a non-US keymap at boot time (y/n)?", "n", False),
        ("Which port contains your modem (if you have one)?", "5", False),
        ("Which type of mouse do you have (if you have one)?", "1", False),
        ("Which port contains your mouse?", "3", False),
        ("What type of serial mouse do you have?", "1", False),
        (
            "Would you like to make a custom bootdisk before proceeding (y/n)?",
            "n",
            False,
        ),
        ("Press <RETURN> to continue...", "", False),
        ("Please select one:", "7", False),
    )
    for question, answer, regex in answers:
        ask(question, answer=answer, regex=regex)
    session.serial.wait("#", line=True)
    session.serial_shell_send("mkdir -p /retro && mount -t msdos /dev/hdb1 /retro")
    session.serial_shell_send("sh /retro/guestlib.d/deb091/lilo.sh /dev/hda2 /root")
    session.serial_shell_send("umount /retro")
    session.set_boot("c")
    session.serial_console_echo("Rebooting...")
    session.serial_shell_send("reboot", wait=False)
    session.vga_wait("debra.retro.net login:", match=Match.LINE)
    session.kb_type("root", enter=True)
    session.vga_wait("[root:~]#", match=Match.LINE)
    session.kb_type(session.postinst_command, enter=True)
