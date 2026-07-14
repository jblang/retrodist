from retro_host.install import Match
from retro_host.install.fdisk import Fdisk


def install(session):
    prompt = session.serial.prompt
    session.vga_wait("darkstar login:", match=Match.LINE)
    session.kb_type("root", enter=True)
    session.serial_shell_start()
    Fdisk(session).partition()
    session.serial.wait("#", line=True)
    session.serial_console_echo(
        "Starting Slackware setup; package installation may take a while..."
    )
    session.serial_shell_send("setup", wait=False)

    answers = (
        (
            (
                "Would you like to remap your keyboard?",
                "1 - yes",
                "2 - no",
                "Your choice (1/2)?",
            ),
            "2",
            False,
        ),
        (
            ("Do you wish to install this partition as your swapspace ([y]es, [n]o)?",),
            "y",
            False,
        ),
        (
            ("Do you want setup to use mkswap on your swap partitions ([y]es, [n]o)?",),
            "y",
            False,
        ),
        (
            ("Would you like to [a]dd more software, or [i]nstall from scratch?",),
            "i",
            False,
        ),
        (
            (
                "What filesystem do you have (or do you plan to use) on your root",
                "partition (/dev/hda2 ), [e]xt2fs or [x]iafs?",
            ),
            "e",
            False,
        ),
        (("Enter [i] again to install from scratch, or [a] to add",), "i", False),
        (
            ("Would you like to format this partition ([y]es, [n]o, [c]heck sectors too)?",),
            "y",
            False,
        ),
        (
            (
                "Would you like to set up some of these partitions to be visible",
                "from Linux ([y]es, [n]o)?",
            ),
            "y",
            False,
        ),
        (
            (
                "Please enter the partition you would like to access from Linux, or",
                "type <q> to quit adding new partitions:",
            ),
            "/dev/hdb1",
            False,
        ),
        (("Where would you like to mount /dev/hdb1?",), "/retro", False),
        (("Done adding partition /dev/hdb1.",), "q", False),
        (("1 -- Install from a hard drive partition.",), "1", False),
        (
            (
                "Please enter the partition where the Slackware sources can be",
                "found, or [p] to see a partition list:",
            ),
            "/dev/hdb1",
            False,
        ),
        (("What directory are the Slackware sources in?",), "/packages", False),
        (
            ("What type of filesystem does your Slackware source partition contain?",),
            "1",
            False,
        ),
        (
            ("Which disk sets do you want to install?",),
            "A AP D E F IV N TCL OI OOP X XAP XD XV Y",
            False,
        ),
        (("Do you want to use PROMPT mode (y/n)?",), "y", False),
        (
            (
                "It is recommended that you make a boot disk.",
                "Would you like to do this ([y]es, [n]o)?",
            ),
            "n",
            False,
        ),
        (("Would you like to set up your modem ([y]es, [n]o)?",), "n", False),
        (("Would you like to set up your mouse ([y]es, [n]o)?",), "n", False),
        (
            (
                "LILO (Linux Loader) Installation:",
                "Which option would you like? (1/2/3/4):",
            ),
            "2",
            False,
        ),
        (("Would you like to configure your network ([y]es, [n]o)?",), "y", False),
        (("Enter hostname:",), "darkstar", False),
        (("Enter domain name for darkstar:",), "retro.net", False),
        (("Do you plan to ONLY use loopback ([y]es, [n]o)?",), "n", False),
        (("Enter IP address for darkstar (aaa.bbb.ccc.ddd):",), "10.0.2.15", False),
        (("Enter network address (aaa.bbb.ccc.ddd):",), "10.0.2.0", False),
        (("Enter gateway address (aaa.bbb.ccc.ddd):",), "10.0.2.2", False),
        (("Enter netmask (aaa.bbb.ccc.ddd):",), "255.255.255.0", False),
        (("Enter broadcast address (aaa.bbb.ccc.ddd):",), "10.0.2.255", False),
        (("Name Server for domain retro.net (aaa.bbb.ccc.ddd):",), "10.0.2.3", False),
        (
            (
                r'Would you like to add "selection -t none &" to /etc/rc.d/rc.local so that',
                "selection will load at boot time ([y]es, [n]o)?",
            ),
            "n",
            False,
        ),
        (("Would you like to configure your timezone ([y]es, [n]o)?",), "y", False),
        (("Select one of these timezones:", "Timezone?"), "US/Central", False),
    )
    for questions, answer, regex in answers:
        prompt(*questions, answer=answer, regex=regex)
    session.serial.wait(
        "You may now reboot your computer by pressing control+alt+delete.", line=True
    )
    session.set_boot("c")
    session.kb_press("ctrl-alt-delete")
    session.vga_wait("darkstar login:", match=Match.LINE)
    session.kb_type("root", enter=True)
    session.vga_wait("darkstar:~#", match=Match.LINE)
    session.kb_type("/retro/guestlib.d/postinst.sh", enter=True)
