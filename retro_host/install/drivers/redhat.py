from __future__ import annotations

from dataclasses import dataclass
import time

from ..fdisk import Fdisk
from ..session import InstallSession, Match


@dataclass(slots=True)
class CInstallerOptions:
    boot_prompt: str = "boot:"
    boot_command: str = ""
    boot_sleep: float = 0
    color_prompt: bool = True
    language_prompt: bool = False
    keyboard_early: bool = False
    keyboard_after_packages: bool = False
    keyboard_late: bool = False
    pcmcia_prompt: bool = True
    cdrom_type_prompt: bool = True
    insert_cd_prompt: str = "Insert your Red Hat CD into your CD drive"
    flow: str = "4x"
    x_card_down: int = 66
    monitor_key: str = "ret"
    timezone_prompt: str = "Configure Timezone"
    lilo_extra_f12: int = 0
    bootdisk_prompt: bool = False
    password: str = "password"
    hostname: str = "redhat"
    domain: str = "retro.net"
    ip: str = "10.0.2.15"
    netmask: str = "255.255.255.0"
    network: str = "10.0.2.0"
    broadcast: str = "10.0.2.255"
    gateway: str = "10.0.2.2"
    nameserver: str = "10.0.2.3"


class CInstaller:
    def __init__(self, session: InstallSession, options: CInstallerOptions) -> None:
        self.s, self.o = session, options

    def step(self, screen: str, *keys: str) -> None:
        self.s.vga_wait(screen)
        self.s.kb_press(*keys)

    def start(self) -> None:
        o = self.o
        self.s.vga_wait(o.boot_prompt, match=Match.LINE)
        self.s.kb_type(o.boot_command, enter=True)
        if o.boot_sleep:
            time.sleep(o.boot_sleep)
        if o.color_prompt:
            self.step("Are you using a color monitor?", "f12")
        self.step("Welcome to Red Hat Linux!", "f12")
        if o.language_prompt:
            self.step("Choose a Language", "f12")
        if o.keyboard_early:
            self.step("Keyboard Type", "f12")
        if o.pcmcia_prompt:
            self.step("Do you need PCMCIA support?", "f12")
        self.step("Installation Method", "f12")
        self.step(o.insert_cd_prompt, "f12")
        if o.cdrom_type_prompt:
            self.step("What type of CDROM do you have?", "f12")
        self.step("Installation Path", "f12")
        self.step("Do you have any SCSI adapters?", "f12")

    def partition_helper(self) -> None:
        self.s.kb_press("alt-f2")
        self.s.serial_shell_start(screen_prompt="bash#")
        Fdisk(self.s).partition()
        self.s.serial.wait("#", line=True)
        self.s.serial_shell_exit(screen_prompt="bash#")
        self.s.kb_press("alt-f1")

    def partition_4x(self) -> None:
        self.s.vga_wait("Partition Disks")
        self.partition_helper()
        self.step("Partition Disks", "f12")
        self.step("Active Swap Space", "f12")
        self.step("Select Root Partition", "f12")
        self.step("You may now mount other partitions within your filesystem.", "down", "ret")
        self.s.vga_wait("Edit Mount Point")
        self.s.kb_type("/retro", enter=True)
        self.s.kb_press("f12")
        self.step("Format Partitions", "spc", "f12")

    def components_40(self) -> None:
        self.s.vga_wait("Components to Install")
        self.s.kb_press("spc")
        self.s.kb_repeat("down", 2)
        self.s.kb_press("spc", "down", "spc")
        self.s.kb_repeat("down", 8)
        self.s.kb_press("spc", "down", "spc", "down", "spc", "down", "spc", "down", "spc")
        self.s.kb_repeat("down", 5)
        self.s.kb_press("spc", "f12")

    def components_default(self) -> None:
        self.step("Components to Install", "f12")

    def finish_components(self) -> None:
        self.step("Install log", "f12")
        if self.o.keyboard_after_packages:
            self.step("Configure Keyboard", "f12")

    def x11_4x(self) -> None:
        self.step("Configure Mouse", "down", "down", "f12")
        self.s.vga_wait("Choose A Card")
        self.s.kb_repeat("down", self.o.x_card_down)
        self.s.kb_press("f12")
        self.step("Monitor Setup", "down", self.o.monitor_key)
        self.s.vga_wait("Video Memory")
        self.s.kb_repeat("down", 4)
        self.s.kb_press("f12")
        self.step("Clockchip Configuration", "f12")
        self.step("Select Video Modes", "f12")

    def x11_5x(self) -> None:
        self.step("X Server : SVGA", "f12")
        self.step("Monitor Setup", "down", "f12")
        self.step("Screen Configuration", "f12")
        self.s.vga_wait("Video Memory")
        self.s.kb_repeat("down", 4)
        self.s.kb_press("f12")
        self.step("Clockchip Configuration", "f12")
        self.step("Select Video Modes", "f12")

    def network(self) -> None:
        o = self.o
        self.step("Network Configuration", "f12")
        if o.flow == "51":
            self.step("Digital 21040 (Tulip)", "f12")
            self.step("Boot Protocol", "f12")
        self.s.vga_wait("Configure TCP/IP")
        self.s.kb_type(o.ip, enter=True)
        for value in (o.netmask, o.network, o.broadcast):
            self.s.kb_repeat("backspace", 15)
            self.s.kb_type(value, enter=True)
        self.s.kb_press("f12")
        self.s.vga_wait("Configure Network")
        self.s.kb_type(o.domain, enter=True)
        self.s.kb_type(o.hostname, enter=True)
        for value in (o.gateway, o.nameserver):
            self.s.kb_repeat("backspace", 15)
            self.s.kb_type(value, enter=True)
        self.s.kb_press("f12")

    def finish(self) -> None:
        o = self.o
        self.step(o.timezone_prompt, "f12")
        if o.keyboard_late:
            self.step("Configure Keyboard", "f12")
        if o.flow in {"50", "51"}:
            self.step("Services", "f12")
        if o.flow == "42":
            self.step("Add Printers", "tab", "ret")
        elif o.flow in {"50", "51"}:
            self.step("Configure Printer", "tab", "ret")
        self.s.vga_wait("Root Password")
        self.s.kb_type(o.password, enter=True)
        self.s.kb_type(o.password, enter=True)
        self.s.kb_press("f12")
        if o.bootdisk_prompt:
            self.step("Bootdisk", "tab", "ret")
        self.s.vga_wait("Lilo Installation")
        self.s.kb_press("f12", *("f12" for _ in range(o.lilo_extra_f12)))
        self.step("Bootable Partitions", "down", "ret")
        self.s.kb_repeat("backspace", 3)
        self.s.kb_press("ret", "f12")
        self.s.vga_wait("Congratulations, installation is complete.")
        self.s.set_boot("c")
        self.s.kb_press("ret")
        self.s.run_postinst(
            o.password,
            login=f"{o.hostname} login:",
            shell=f"[root@{o.hostname} /root]#",
        )
