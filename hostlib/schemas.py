"""Typed Pydantic schemas for declarative ``config.toml`` sections.

These models form a strict boundary around untrusted TOML data and remain the
typed representation used by host subsystems. This centralizes field names,
defaults, nested table shapes, and cross-field constraints.
"""

from __future__ import annotations

import platform
from typing import Annotated, Literal, TypeVar

from pydantic import BaseModel, ConfigDict, Field, ValidationError, model_validator

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
        location = _location(path, error["loc"])
        message = str(error["msg"]).removeprefix("Value error, ")
        if path == "download" and error["type"] == "missing" and error["loc"][-1] == "url":
            number = int(error["loc"][-2]) + 1
            raise ConfigError(f"Missing URL for download.files entry {number}") from exc
        if path == "install" and error["type"] == "too_short":
            raise ConfigError("prompt-sequence driver requires install.steps") from exc
        if path == "install" and error["loc"] == ("driver",):
            raise ConfigError("config.toml must set install.driver") from exc
        if path == "install" and "keys" in error["loc"]:
            number = int(error["loc"][1]) + 1
            raise ConfigError(f"install.steps entry {number} keys must be strings") from exc
        if path == "postinst" and error["type"] == "literal_error":
            raise ConfigError(f"Unknown post-install stage(s): {error['input']}") from exc
        if path == "install.redhat" and error["loc"] == ("flow",):
            raise ConfigError("install.redhat.flow must be a string") from exc
        descriptions = {
            "bool_type": "must be a boolean",
            "dict_type": "must be a table",
            "float_type": "must be a number",
            "int_type": "must be an integer",
            "list_type": (
                "must be an array of strings"
                if error["loc"]
                and error["loc"][-1]
                in {"decompress", "extra_images", "fat_files", "members", "truncate"}
                else (
                    "must be an array of tables"
                    if error["loc"] and error["loc"][-1] == "files"
                    else "must be an array"
                )
            ),
            "literal_error": message,
            "model_type": "must be a table",
            "missing": "is required",
            "string_type": "must be a string",
        }
        description = descriptions.get(str(error["type"]), message)
        raise ConfigError(f"{location} {description}") from exc


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


class ImageExtract(ConfigModel):
    """Validate one disk-image extraction operation."""

    image: str
    members: list[str]
    destination: str
    lowercase: bool = False


class ArchiveExtract(ConfigModel):
    """Validate one tar archive extraction operation."""

    archive: str
    members: list[str]
    destination: str
    flatten: bool = False


class ExtractionConfig(ConfigModel):
    """Configure the complete declarative media-staging plan."""

    source: str = ""
    boot_image: str | None = None
    root_image: str | None = None
    extra_images: list[str] = Field(default_factory=list)
    fat_files: list[str] = Field(default_factory=list)
    package_source: str | None = None
    package_dest: str = "packages"
    decompress: list[str] = Field(default_factory=list)
    truncate: list[str] = Field(default_factory=list)
    boot_link: str | None = None
    root_link: str | None = None
    custom_script: str | None = None
    custom_source: str | None = None
    overlays: list[Overlay] = Field(default_factory=list)
    image_extracts: list[ImageExtract] = Field(default_factory=list)
    archive_extracts: list[ArchiveExtract] = Field(default_factory=list)

    @model_validator(mode="after")
    def custom_script_has_source(self) -> "ExtractionConfig":
        """Require an extraction source when a custom script is configured."""
        if self.custom_script and not self.custom_source:
            raise ValueError("extract.custom_script requires extract.custom_source")
        return self


Scalar = str | int | bool


class PostinstConfig(ConfigModel):
    """Configure host-rendered post-installation behavior."""

    stages: list[Literal["modules", "network", "tty", "x11", "custom"]] = Field(
        default_factory=list
    )
    custom_script: str | None = None
    debug: bool | None = None
    log: str | None = None
    reboot: bool | None = None
    modules: dict[str, Scalar] = Field(default_factory=dict)
    network: dict[str, Scalar] = Field(default_factory=dict)
    tty: dict[str, Scalar] = Field(default_factory=dict)
    x11: dict[str, Scalar] = Field(default_factory=dict)
    custom: dict[str, Scalar] = Field(default_factory=dict)

    @model_validator(mode="after")
    def custom_stage_has_script(self) -> "PostinstConfig":
        """Require a script whenever the custom post-install stage is enabled."""
        if "custom" in self.stages and self.custom_script is None:
            raise ValueError("Custom post-install stage requires postinst.custom_script")
        return self


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
