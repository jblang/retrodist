"""Compatibility exports and typed media, guest, and installer schemas."""

from __future__ import annotations

from typing import Annotated, Literal

from pydantic import (
    ConfigDict,
    Field,
    RootModel,
    model_validator,
)

from .media_schemas import (
    DebianPackageMountConfig,
    DebianPackagePrompt,
    DebianPackagesConfig,
    DownloadConfig,
    DownloadFile,
    ExtractionConfig,
    NetworkConfig,
    Overlay,
    PostinstConfig,
    PostinstNetworkConfig,
    Scalar,
)
from .qemu_schemas import (
    QEMU_PROFILES,
    PortForward,
    QemuConfig,
    QemuDisk,
    QemuDisplay,
    QemuNetwork,
    QemuProfile,
    QemuSerial,
)
from .schema_base import ConfigModel, validate


class InstallDiskConfig(ConfigModel):
    """Configure paths and partition defaults shared by installer drivers."""

    target_disk: str = "/dev/hda"
    swap_mb: int = 64
    fat_partition: str = "/dev/hdb1"
    fat_mount: str = "/retro"
    fat_filesystem: str = "msdos"


class InstallLocaleConfig(ConfigModel):
    """Configure installer locale choices shared by family drivers."""

    keymap: str = "us"
    timezone: str = "UTC"


class InstallPromptsConfig(ConfigModel):
    """Configure prompts shared by installer lifecycle variants."""

    boot_prompt: str = "boot:"
    boot_command: str = ""
    boot_sleep: float = 0
    postinst_prompt: str | None = None


class DinstallNetworkConfig(NetworkConfig):
    """Add Debian installer module controls to static networking."""

    net_module: str | None = None
    net_module_args: str = ""


class DinstallSettings(ConfigModel):
    """Configure Debian Dinstall-specific choices."""

    configure_keyboard: bool = False
    kernel_floppy: str | None = None
    driver_floppy: str | Literal[False] | None = "drv1440.bin"
    relogin: bool = False
    fs_module: str | None = None
    root_password: str = "password1"
    user: str = "debian"
    user_password: str = "password1"
    fat_filesystem: str | None = None


class PkgtoolDiskConfig(InstallDiskConfig):
    """Add Slackware target partition choices to common install paths."""

    linux_partition: str = "/dev/hda2"
    linux_partition_name: str = "linux"


class PkgtoolSettings(ConfigModel):
    """Configure Slackware Pkgtool-specific choices."""

    setup_hostname: str = "slackware"
    source: str = "/dev/hdc"
    lilo_framebuffer: str = "standard"
    install_mode: str | None = None
    tagfile_path: str | Literal[False] | None = "/retro/tagfiles"
    package_sets: str = '"A" "AP" "N" "X" "XAP"'
    modem_speed: str = "38400"
    sendmail_mode: str = "SMTP"
    xwmconfig: bool = False
    source_before_target: bool = False
    simple_lilo: bool = False


class CInstallerSettings(ConfigModel):
    """Configure Red Hat C-installer-specific screens and navigation."""

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


class PerlInstallerSettings(ConfigModel):
    """Select the early Red Hat Perl-installer flow."""

    flow: str


class SysinstallDiskConfig(ConfigModel):
    """Configure early Slackware Sysinstall disk paths and sizes."""

    target_disk: str = "/dev/hda"
    swap_mb: int = 64
    swap_partition: str = "/dev/hda1"
    swap_blocks: int = 64000
    linux_partition: str = "/dev/hda2"
    fat_partition: str = "/dev/hdb1"


class DinstallBootConfig(ConfigModel):
    """Configure Debian installer boot and root-disk prompts."""

    prompt: str = "boot:"
    command: str = ""
    root_prompt: str | None = None
    root_image: str = "root.img"


class PkgtoolBootConfig(ConfigModel):
    """Configure Slackware installer boot and root-disk prompts."""

    boot_prompt: str | Literal[False] | None = "boot:"
    root_prompt: str | Literal[False] | None = None
    root_image: str = "root.img"
    continuation_prompt: str | Literal[False] | None = None
    keyboard_prompt: bool = False


class UnattendedBootConfig(ConfigModel):
    """Configure unattended Red Hat boot input."""

    prompt: str = "boot:"
    command: str


class UnattendedCompletionConfig(ConfigModel):
    """Configure unattended Red Hat completion handling."""

    prompt: str
    reboot: bool = True
    postinst: bool = False
    boot_device: str = "c"


class UnattendedAccountsConfig(ConfigModel):
    """Configure credentials used after an unattended installation."""

    root_password: str | None = None


class UnattendedPromptsConfig(ConfigModel):
    """Configure login prompts used after an unattended installation."""

    login_prompt: str = "login:"
    shell_prompt: str = "#"


class UnattendedInstallConfig(ConfigModel):
    """Configure an unattended Red Hat installation lifecycle."""

    driver: Literal["redhat-unattended"]
    boot: UnattendedBootConfig
    completion: UnattendedCompletionConfig
    accounts: UnattendedAccountsConfig = Field(default_factory=UnattendedAccountsConfig)
    prompts: UnattendedPromptsConfig = Field(default_factory=UnattendedPromptsConfig)


class DinstallInstallConfig(ConfigModel):
    """Validate the complete Debian Dinstall configuration."""

    driver: Literal["debian-dinstall"]
    boot: DinstallBootConfig = Field(default_factory=DinstallBootConfig)
    disk: InstallDiskConfig = Field(default_factory=InstallDiskConfig)
    locale: InstallLocaleConfig = Field(
        default_factory=lambda: InstallLocaleConfig(timezone="Etc/UTC")
    )
    network: DinstallNetworkConfig = Field(
        default_factory=lambda: DinstallNetworkConfig(hostname="debian")
    )
    debian: DinstallSettings = Field(default_factory=DinstallSettings)


class PkgtoolInstallConfig(ConfigModel):
    """Validate the complete Slackware Pkgtool configuration."""

    driver: Literal["slackware-pkgtool"]
    boot: PkgtoolBootConfig = Field(default_factory=PkgtoolBootConfig)
    disk: PkgtoolDiskConfig = Field(default_factory=PkgtoolDiskConfig)
    locale: InstallLocaleConfig = Field(default_factory=InstallLocaleConfig)
    network: NetworkConfig = Field(default_factory=lambda: NetworkConfig(hostname="darkstar"))
    prompts: InstallPromptsConfig = Field(default_factory=InstallPromptsConfig)
    slackware: PkgtoolSettings = Field(default_factory=PkgtoolSettings)


class CInstallConfig(ConfigModel):
    """Validate the complete Red Hat C-installer configuration."""

    driver: Literal["redhat-c"]
    disk: InstallDiskConfig = Field(default_factory=InstallDiskConfig)
    prompts: InstallPromptsConfig = Field(default_factory=InstallPromptsConfig)
    network: NetworkConfig = Field(default_factory=lambda: NetworkConfig(hostname="redhat"))
    redhat: CInstallerSettings = Field(default_factory=CInstallerSettings)


class PerlInstallConfig(ConfigModel):
    """Validate the complete Red Hat Perl-installer configuration."""

    driver: Literal["redhat-perl"]
    disk: InstallDiskConfig = Field(default_factory=InstallDiskConfig)
    prompts: InstallPromptsConfig = Field(default_factory=InstallPromptsConfig)
    network: NetworkConfig = Field(default_factory=lambda: NetworkConfig(hostname="redhat"))
    redhat: PerlInstallerSettings


class SysinstallInstallConfig(ConfigModel):
    """Validate the complete early Slackware Sysinstall configuration."""

    driver: Literal["slackware-sysinstall"]
    disk: SysinstallDiskConfig = Field(default_factory=SysinstallDiskConfig)


class CommonInstallConfig(InstallDiskConfig):
    """Configure paths and partition defaults shared by installer actions."""


class Step(ConfigModel):
    """Common discriminator shared by all prompt-sequence actions."""


class WaitStep(Step):
    """Validate a VGA or serial wait action."""

    action: Literal["wait"]
    transport: Literal["vga", "serial"] = "vga"
    text: str
    match: Literal["text", "line", "regex"] = "text"
    timeout: float | None = None


class TypeStep(Step):
    """Validate a keyboard typing action."""

    action: Literal["type"]
    text: str


class PressStep(Step):
    """Validate a literal key-press action."""

    action: Literal["press"]
    keys: str | list[str]
    repeat: int = Field(default=1, ge=1)


class PromptStep(Step):
    """Validate a VGA or serial prompt-and-answer action."""

    action: Literal["prompt"]
    transport: Literal["vga", "serial"] = "serial"
    questions: str | list[str] | None = None
    text: str | None = None
    answer: str = ""
    regex: bool = False

    @model_validator(mode="after")
    def has_questions(self) -> "PromptStep":
        """Require either the singular text form or one or more questions."""
        if self.questions is None and self.text is None:
            raise ValueError("requires prompt questions")
        return self


class SerialShellStartStep(Step):
    """Validate an interactive serial-shell start action."""

    action: Literal["serial-shell-start"]
    screen_prompt: str = "#"
    serial_prompt: str = "#"


class SerialShellSendStep(Step):
    """Validate one or more interactive serial-shell commands."""

    action: Literal["serial-shell-send"]
    command: str | list[str]
    wait: bool = True
    prompt: str = "#"


class SerialSendStep(Step):
    """Validate a raw serial send action."""

    action: Literal["serial-send"]
    text: str = ""


class SerialShellExitStep(Step):
    """Validate an interactive serial-shell exit action."""

    action: Literal["serial-shell-exit"]
    screen_prompt: str = "#"


class ConsoleEchoStep(Step):
    """Validate a visible guest-console message action."""

    action: Literal["console-echo"]
    text: str


class PartitionStep(Step):
    """Validate a disk partitioning action."""

    action: Literal["partition"]
    device: str | None = None
    swap_mb: int | None = None


class ChangeFloppyStep(Step):
    """Validate a floppy replacement action."""

    action: Literal["change-floppy"]
    image: str


class SetBootStep(Step):
    """Validate a QEMU boot-device change action."""

    action: Literal["set-boot"]
    device: str


class RunPostinstStep(Step):
    """Validate an installed-system post-install action."""

    action: Literal["run-postinst"]
    password: str | None = None
    login: str = "login:"
    shell: str = "#"


InstallStep = Annotated[
    WaitStep
    | TypeStep
    | PressStep
    | PromptStep
    | SerialShellStartStep
    | SerialShellSendStep
    | SerialSendStep
    | SerialShellExitStep
    | ConsoleEchoStep
    | PartitionStep
    | ChangeFloppyStep
    | SetBootStep
    | RunPostinstStep,
    Field(discriminator="action"),
]


class PromptSequenceConfig(ConfigModel):
    """Configure a non-empty sequence of discriminated installer actions."""

    default_transport: Literal["vga", "serial"] | None = None
    steps: list[InstallStep] = Field(min_length=1)

    @model_validator(mode="before")
    @classmethod
    def apply_default_transport(cls, data: object) -> object:
        """Apply the configured transport to waits and prompts that omit one."""
        if not isinstance(data, dict):
            return data
        default = data.get("default_transport")
        steps = data.get("steps")
        if default not in {"vga", "serial"} or not isinstance(steps, list):
            return data
        resolved = dict(data)
        resolved["steps"] = [
            {**step, "transport": default}
            if isinstance(step, dict)
            and step.get("action") in {"wait", "prompt"}
            and "transport" not in step
            else step
            for step in steps
        ]
        return resolved


class PromptSequenceInstallConfig(PromptSequenceConfig):
    """Validate a prompt sequence while retaining interpolation data tables."""

    driver: Literal["prompt-sequence"]
    model_config = ConfigDict(strict=True, extra="allow", frozen=True)


InstallConfig = Annotated[
    DinstallInstallConfig
    | PkgtoolInstallConfig
    | CInstallConfig
    | PerlInstallConfig
    | UnattendedInstallConfig
    | SysinstallInstallConfig
    | PromptSequenceInstallConfig,
    Field(discriminator="driver"),
]


class InstallConfigModel(RootModel[InstallConfig]):
    """Wrap the discriminated installer union for shared error translation."""
