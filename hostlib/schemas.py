"""Typed Pydantic schemas for declarative ``config.toml`` sections.

These models form a strict boundary around untrusted TOML data and remain the
typed representation used by host subsystems. This centralizes field names,
defaults, nested table shapes, and cross-field constraints.
"""

from __future__ import annotations

import platform
from typing import Annotated, Literal, TypeVar

from pydantic import AliasChoices, BaseModel, ConfigDict, Field, ValidationError, model_validator

from .errors import ConfigError


class ConfigModel(BaseModel):
    """Base schema that rejects coercion and unknown configuration fields."""

    model_config = ConfigDict(strict=True, extra="forbid")


Model = TypeVar("Model", bound=ConfigModel)


def validate(cls: type[Model], data: object, path: str) -> Model:
    """Validate one config section and translate errors to ``ConfigError``."""
    try:
        return cls.model_validate(data)
    except ValidationError as exc:
        errors = exc.errors()
        extras = [error for error in errors if error["type"] == "extra_forbidden"]
        if extras:
            names = ", ".join(sorted(str(error["loc"][-1]) for error in extras))
            raise ConfigError(f"Unknown {path} setting(s): {names}") from exc
        error = errors[0]
        if special := _special_validation_message(path, error):
            raise ConfigError(special) from exc
        raise ConfigError(
            f"{_location(path, error['loc'])} {_validation_description(error, path)}"
        ) from exc


def _special_validation_message(path: str, error: dict[str, object]) -> str | None:
    """Return a tailored message for configuration errors needing extra context."""
    location = error["loc"]
    error_type = error["type"]
    assert isinstance(location, tuple)
    if path == "download" and error_type == "missing" and location[-1] == "url":
        return f"Missing URL for download.files entry {int(location[-2]) + 1}"
    if path == "install" and error_type == "too_short":
        return "prompt-sequence driver requires install.steps"
    if path == "install" and location == ("driver",):
        return "config.toml must set install.driver"
    if path == "install" and "keys" in location:
        return f"install.steps entry {int(location[1]) + 1} keys must be strings"
    if path == "postinst" and error_type == "literal_error":
        return f"Unknown post-install stage(s): {error['input']}"
    if path == "install.redhat" and location == ("flow",):
        return "install.redhat.flow must be a string"
    return None


def _validation_description(error: dict[str, object], path: str) -> str:
    """Translate a Pydantic error type into configuration-oriented language."""
    message = str(error["msg"]).removeprefix("Value error, ")
    descriptions = {
        "bool_type": "must be a boolean",
        "dict_type": "must be a table",
        "float_type": "must be a number",
        "int_type": "must be an integer",
        "list_type": _list_error_description(error["loc"], path),
        "literal_error": message,
        "model_type": "must be a table",
        "missing": "is required",
        "string_type": "must be a string",
    }
    return descriptions.get(str(error["type"]), message)


def _list_error_description(location: object, path: str) -> str:
    """Describe the expected list shape using the failing field name."""
    assert isinstance(location, tuple)
    if location and location[-1] in {
        "decompress",
        "extra_images",
        "fat_files",
        "package_sources",
        "truncate",
    }:
        return "must be an array of strings"
    if path == "extract" and location and location[-1] == "files":
        return "must be an array of strings"
    return (
        "must be an array of tables"
        if path == "download" and location and location[-1] == "files"
        else "must be an array"
    )


def _location(path: str, parts: tuple[object, ...]) -> str:
    """Render a Pydantic error location using TOML-oriented notation."""
    result = path
    for part in parts:
        if isinstance(part, int):
            result += f" entry {part + 1}"
        else:
            result += f".{part}"
    return result


class QemuDisk(ConfigModel):
    """Validate the nested QEMU disk table."""

    size: str | None = None
    format: str = "qcow2"
    create_options: str | None = None
    hda_options: str | None = None
    floppy_a_type: str | None = "144"
    floppy_b_type: str | None = "144"


PortForward = Annotated[list[int], Field(min_length=2, max_length=2)]


class QemuNetwork(ConfigModel):
    """Validate the nested QEMU network table."""

    device: str | None = None
    enabled: bool = True
    forwards: list[PortForward] | None = None


class QemuDisplay(ConfigModel):
    """Validate the nested QEMU display table."""

    backend: str = Field(
        default_factory=lambda: "cocoa" if platform.system() == "Darwin" else "gtk"
    )
    acceleration: str | None = None
    vga: str | None = None


class QemuSerial(ConfigModel):
    """Validate the nested QEMU serial table."""

    auxiliary: str | None = "null"


class QemuProfile(ConfigModel):
    """Store one named set of era-specific QEMU hardware defaults."""

    model_config = ConfigDict(strict=True, extra="forbid", frozen=True)

    machine: str
    ram: str
    disk_size: str
    nic: str
    vga: str | None = None
    acceleration: str | None = None


QEMU_PROFILES = {
    "default": QemuProfile(machine="type=isapc", ram="16M", disk_size="500M", nic="ne2k_isa"),
    "linux-0.99": QemuProfile(machine="type=isapc", ram="64M", disk_size="500M", nic="ne2k_isa"),
    "linux-1.0": QemuProfile(machine="type=isapc", ram="64M", disk_size="512M", nic="ne2k_isa"),
    "linux-1.2": QemuProfile(
        machine="type=isapc",
        ram="64M",
        disk_size="2G",
        nic="ne2k_isa",
        acceleration="tcg",
    ),
    "linux-2.0-isa": QemuProfile(machine="type=isapc", ram="64M", disk_size="2G", nic="ne2k_isa"),
    "linux-2.0": QemuProfile(
        machine="type=pc", ram="64M", disk_size="8G", nic="tulip", vga="cirrus"
    ),
    "linux-2.2": QemuProfile(
        machine="type=pc", ram="64M", disk_size="8G", nic="tulip", vga="cirrus"
    ),
    "linux-2.4": QemuProfile(
        machine="type=pc", ram="128M", disk_size="8G", nic="tulip", vga="std"
    ),
}


class QemuConfig(ConfigModel):
    """Validate and resolve the nested QEMU runtime configuration."""

    profile: str = "default"
    system: str = "qemu-system-i386"
    machine: str | None = None
    ram: str | None = None
    smp: int = 1
    boot_order: str | None = None
    extra: list[str] = Field(default_factory=list)
    disk: QemuDisk = Field(default_factory=QemuDisk)
    network: QemuNetwork = Field(default_factory=QemuNetwork)
    display: QemuDisplay = Field(default_factory=QemuDisplay)
    serial: QemuSerial = Field(default_factory=QemuSerial)

    @model_validator(mode="after")
    def apply_profile(self) -> "QemuConfig":
        """Fill unset hardware settings from the selected QEMU profile."""
        try:
            profile = QEMU_PROFILES[self.profile]
        except KeyError as exc:
            raise ValueError(f"Unknown QEMU profile {self.profile!r}") from exc
        self.machine = self.machine or profile.machine
        self.ram = self.ram or profile.ram
        self.disk.size = self.disk.size or profile.disk_size
        self.network.device = self.network.device or profile.nic
        self.display.vga = self.display.vga or profile.vga
        self.display.acceleration = self.display.acceleration or profile.acceleration or "tcg"
        return self


class DownloadFile(ConfigModel):
    """Validate one direct download declaration."""

    path: str
    url: str


class DownloadConfig(ConfigModel):
    """Configure direct files and supported distribution mirrors."""

    cdrom: str | None = None
    files: list[DownloadFile] = Field(default_factory=list)
    slackware_mirror: str | None = None
    debian_mirror: str | None = None


class Overlay(ConfigModel):
    """Validate one staged-media overlay operation."""

    source: str
    destination: str


class ExtractionConfig(ConfigModel):
    """Configure the complete declarative media-staging plan."""

    source: str = ""
    boot_image: str | None = None
    root_image: str | None = None
    extra_images: list[str] = Field(default_factory=list)
    files: list[str] = Field(default_factory=list)
    fat_files: list[str] = Field(default_factory=list)
    package_source: str | None = None
    package_sources: list[str] = Field(default_factory=list)
    package_index: str | None = None
    package_dest: str = "packages"
    decompress: list[str] = Field(default_factory=list)
    truncate: list[str] = Field(default_factory=list)
    boot_link: str | None = None
    root_link: str | None = None
    custom_script: str | None = None
    overlays: list[Overlay] = Field(default_factory=list)

    @model_validator(mode="after")
    def package_source_forms_do_not_conflict(self) -> "ExtractionConfig":
        """Reject simultaneous use of the singular and plural package selectors."""
        if self.package_source is not None and self.package_sources:
            raise ValueError("extract.package_source and package_sources are mutually exclusive")
        return self


Scalar = str | int | bool


class NetworkConfig(ConfigModel):
    """Describe static guest networking shared by installers and guestlib.

    Defaults match QEMU user networking. ``domainname`` and ``ipaddr`` remain
    accepted as compatibility spellings for the canonical ``domain`` and ``ip``
    fields. This model describes guest configuration; ``QemuNetwork`` separately
    controls emulated hardware and host port forwarding.
    """

    hostname: str = "localhost"
    domain: str = Field(
        default="retro.net",
        validation_alias=AliasChoices("domain", "domainname"),
    )
    ip: str = Field(
        default="10.0.2.15",
        validation_alias=AliasChoices("ip", "ipaddr"),
    )
    netmask: str = "255.255.255.0"
    network: str = "10.0.2.0"
    broadcast: str = "10.0.2.255"
    gateway: str = "10.0.2.2"
    nameserver: str = "10.0.2.3"


class PostinstNetworkConfig(NetworkConfig):
    """Add guestlib compatibility controls to canonical static networking.

    The renderer emits only fields explicitly present in ``[postinst.network]``
    so omitted values continue to be supplied by the portable guest shell code.
    """

    ancient_route: int | bool | None = None
    hostname_init_set: int | bool | None = None
    gateway_hwaddr: str | None = None
    nameserver_hwaddr: str | None = None
    ifconfig_path: str | None = None
    route_path: str | None = None
    arp_path: str | None = None


class DebianPackageMountConfig(ConfigModel):
    """Describe package media that the generated guest script must mount."""

    device: str
    point: str = "/cdrom"
    filesystem: str = "iso9660"
    options: str | None = None


class DebianPackagePrompt(ConfigModel):
    """Match one package-configurator question on the automation serial port."""

    expect: str
    answer: str
    regex: bool = False


class DebianPackagesConfig(ConfigModel):
    """Select Debian packages and locate their guest installation media."""

    roots: list[str] = Field(default_factory=lambda: ["/retro/packages"], min_length=1)
    priorities: list[str] = Field(default_factory=list)
    add: list[str] = Field(default_factory=list)
    skip: list[str] = Field(default_factory=list)
    sections: dict[str, list[str]] = Field(default_factory=dict)
    prompts: list[DebianPackagePrompt] = Field(default_factory=list)
    mount: DebianPackageMountConfig | None = None


class PostinstConfig(ConfigModel):
    """Configure host-rendered post-installation behavior."""

    stages: list[Literal["packages", "modules", "network", "tty", "x11", "custom"]] = Field(
        default_factory=list
    )
    fat_filesystem: str | None = None
    custom_script: str | None = None
    debug: bool | None = None
    log: str | None = None
    reboot: bool | None = None
    modules: dict[str, Scalar] = Field(default_factory=dict)
    network: PostinstNetworkConfig = Field(default_factory=PostinstNetworkConfig)
    packages: DebianPackagesConfig = Field(default_factory=DebianPackagesConfig)
    tty: dict[str, Scalar] = Field(default_factory=dict)
    x11: dict[str, Scalar] = Field(default_factory=dict)
    custom: dict[str, Scalar] = Field(default_factory=dict)

    @model_validator(mode="after")
    def validate_stages(self) -> "PostinstConfig":
        """Validate stage-specific post-install requirements."""
        if "custom" in self.stages and self.custom_script is None:
            raise ValueError("Custom post-install stage requires postinst.custom_script")
        if self.packages.prompts and "packages" not in self.stages:
            raise ValueError("Package prompts require the packages post-install stage")
        return self

    @property
    def reboots(self) -> bool:
        """Return whether the configured guest runner finishes by rebooting."""
        return self.reboot is True or bool(
            {"modules", "network", "tty"}.intersection(self.stages)
        )


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


class RedhatFlowConfig(ConfigModel):
    """Select one early Red Hat Perl-installer flow."""

    flow: str


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

    boot: UnattendedBootConfig
    completion: UnattendedCompletionConfig
    accounts: UnattendedAccountsConfig = Field(default_factory=UnattendedAccountsConfig)
    prompts: UnattendedPromptsConfig = Field(default_factory=UnattendedPromptsConfig)


class CommonInstallConfig(ConfigModel):
    """Configure paths and partition defaults shared by installer actions."""

    target_disk: str = "/dev/hda"
    swap_mb: int = 64
    fat_mount: str = "/retro"
    fat_partition: str = "/dev/hdb1"
    fat_filesystem: str = "msdos"


class InstallDriverConfig(ConfigModel):
    """Select the installer driver for a distribution configuration."""

    driver: str


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
    """Validate a serial prompt-and-answer action."""

    action: Literal["prompt"]
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
    """Validate an interactive serial-shell command action."""

    action: Literal["serial-shell-send"]
    command: str
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

    steps: list[InstallStep] = Field(min_length=1)
