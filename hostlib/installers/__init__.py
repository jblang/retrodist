"""Validate and dispatch declarative installer configuration.

Named family drivers handle installers with reusable branching behavior. The
``prompt-sequence`` driver is intentionally bounded to a registry of simple,
validated actions for exceptional linear flows. Both paths operate through the
synchronous ``InstallSession`` API.
"""

from __future__ import annotations

import re
from typing import Any, Callable

from ..config import RetroConfig, reject_unknown
from ..errors import ConfigError
from ..fdisk import Fdisk
from ..session import InstallSession, Match
from .debian import DinstallOptions, run_dinstall
from .redhat import CInstallerOptions, run_c_installer, run_unattended
from .redhat_early import PerlInstallerOptions, run_perl_installer
from .slackware import PkgtoolOptions, run_pkgtool
from .slackware_early import SysinstallOptions, run_sysinstall

Driver = Callable[[InstallSession, dict[str, Any]], None]
StepHandler = Callable[[InstallSession, dict[str, Any]], None]


def run_configured_install(session: InstallSession) -> None:
    """Validate and run the installer driver selected by configuration.

    Driver code receives both the shared session and the original logical
    ``[install]`` table; option dataclasses are resolved by the driver wrapper.
    """
    install = session.config.section("install")
    entrypoint = validate_install_config(session.config)
    entrypoint(session, install)


def validate_install_config(config: RetroConfig) -> Driver:
    """Validate the selected installer driver and return its entry point.

    Validation covers driver-specific option leaves, control tables, and every
    prompt-sequence action before QEMU starts.

    Raises:
        ConfigError: If the driver, options, or declarative steps are invalid.
    """
    install = config.section("install")
    driver = install.get("driver")
    if not isinstance(driver, str):
        raise ConfigError("config.toml must set install.driver")
    try:
        entrypoint = DRIVERS[driver]
    except KeyError as exc:
        raise ConfigError(f"Unknown install driver: {driver}") from exc
    _validate_driver_controls(install, driver)
    if options := DRIVER_OPTIONS.get(driver):
        config.options(options)
        known = set(options.__dataclass_fields__) | DRIVER_CONTROL_FIELDS.get(driver, set())
        unknown = set(config.install_values) - known
        if unknown:
            raise ConfigError(
                f"Unknown install option(s) for {driver}: {', '.join(sorted(unknown))}"
            )
    elif driver == "redhat-unattended":
        known = {
            "command",
            "login_prompt",
            "postinst",
            "prompt",
            "reboot",
            "root_password",
            "shell_prompt",
            "boot_device",
        }
        unknown = set(config.install_values) - known
        if unknown:
            raise ConfigError(
                "Unknown install option(s) for redhat-unattended: " + ", ".join(sorted(unknown))
            )
    if driver == "prompt-sequence":
        steps = install.get("steps")
        if not isinstance(steps, list) or not steps:
            raise ConfigError("prompt-sequence driver requires install.steps")
        for number, step in enumerate(steps, 1):
            if not isinstance(step, dict):
                raise ConfigError(f"install.steps entry {number} must be a table")
            _validate_step(step, number)
    return entrypoint


def _validate_driver_controls(install: dict[str, Any], driver: str) -> None:
    """Validate options accepted by a family installer driver."""
    if driver in {"debian-dinstall", "slackware-pkgtool", "redhat-unattended"}:
        boot = install.get("boot", {})
        if not isinstance(boot, dict):
            raise ConfigError("install.boot must be a table")
        for key, value in boot.items():
            if driver == "slackware-pkgtool" and key in {
                "boot_prompt",
                "root_prompt",
                "continuation_prompt",
            }:
                valid = isinstance(value, str) or value is False
            else:
                expected = bool if key == "keyboard_prompt" else str
                valid = isinstance(value, expected)
            if not valid:
                raise ConfigError(f"install.boot.{key} has the wrong type")
    if driver == "redhat-unattended":
        completion = install.get("completion", {})
        if not isinstance(completion, dict):
            raise ConfigError("install.completion must be a table")
        for key, value in completion.items():
            expected = bool if key in {"reboot", "postinst"} else str
            if not isinstance(value, expected):
                raise ConfigError(f"install.completion.{key} has the wrong type")
    if driver == "redhat-perl":
        redhat = install.get("redhat", {})
        if not isinstance(redhat, dict) or not isinstance(redhat.get("flow"), str):
            raise ConfigError("install.redhat.flow must be a string")


def _validate_step(step: dict[str, Any], number: int) -> None:
    """Validate one declarative prompt-sequence step."""
    action = step.get("action")
    if not isinstance(action, str) or action not in STEP_HANDLERS:
        raise ConfigError(f"Unknown install step action at entry {number}: {action}")
    fields = {
        "wait": {"action", "transport", "text", "match", "timeout"},
        "type": {"action", "text"},
        "press": {"action", "keys", "repeat"},
        "prompt": {"action", "questions", "text", "answer", "regex"},
        "serial-shell-start": {"action", "screen_prompt", "serial_prompt"},
        "serial-shell-send": {"action", "command", "wait", "prompt"},
        "serial-send": {"action", "text"},
        "serial-shell-exit": {"action", "screen_prompt"},
        "console-echo": {"action", "text"},
        "partition": {"action", "device", "swap_mb"},
        "change-floppy": {"action", "image"},
        "set-boot": {"action", "device"},
        "run-postinst": {"action", "password", "login", "shell"},
    }
    reject_unknown(step, fields[action], f"install.steps entry {number}")
    required_strings = {
        "wait": ("text",),
        "type": ("text",),
        "serial-shell-send": ("command",),
        "console-echo": ("text",),
        "change-floppy": ("image",),
        "set-boot": ("device",),
    }
    for key in required_strings.get(action, ()):
        _required_string(step, key)
    for key in (
        "transport",
        "match",
        "answer",
        "screen_prompt",
        "serial_prompt",
        "prompt",
        "text",
        "device",
        "password",
        "login",
        "shell",
    ):
        if key in step and not isinstance(step[key], str):
            raise ConfigError(f"install.steps entry {number} {key} must be a string")
    for key in ("regex", "wait"):
        if key in step and not isinstance(step[key], bool):
            raise ConfigError(f"install.steps entry {number} {key} must be a boolean")
    for key in ("repeat", "swap_mb"):
        if key in step and (not isinstance(step[key], int) or isinstance(step[key], bool)):
            raise ConfigError(f"install.steps entry {number} {key} must be an integer")
    if action == "press":
        keys = step.get("keys")
        if not (
            isinstance(keys, str)
            or isinstance(keys, list)
            and all(isinstance(key, str) for key in keys)
        ):
            raise ConfigError(f"install.steps entry {number} keys must be strings")
    if action == "prompt":
        questions = step.get("questions", step.get("text"))
        if not (
            isinstance(questions, str)
            or isinstance(questions, list)
            and all(isinstance(question, str) for question in questions)
        ):
            raise ConfigError(f"install.steps entry {number} requires prompt questions")
    timeout = step.get("timeout")
    if timeout is not None and (
        not isinstance(timeout, (int, float)) or isinstance(timeout, bool)
    ):
        raise ConfigError(f"install.steps entry {number} timeout must be a number")


def _prompt_sequence(session: InstallSession, install: dict[str, Any]) -> None:
    """Execute the configured linear prompt sequence in declaration order.

    Values such as ``${install.network.hostname}`` are expanded immediately
    before each action, allowing steps to reuse logically grouped settings.
    """
    steps = install.get("steps")
    if not isinstance(steps, list):
        raise ConfigError("prompt-sequence driver requires install.steps")
    for number, step in enumerate(steps, 1):
        if not isinstance(step, dict):
            raise ConfigError(f"install.steps entry {number} must be a table")
        _run_step(session, step, number)


def _run_step(session: InstallSession, step: dict[str, Any], number: int) -> None:
    """Dispatch one declarative installer action."""
    action = step.get("action")
    if not isinstance(action, str):
        raise ConfigError(f"install.steps entry {number} has no action")
    try:
        handler = STEP_HANDLERS[action]
    except KeyError as exc:
        raise ConfigError(f"Unknown install step action: {action}")
    handler(session, step)


def _wait(session: InstallSession, step: dict[str, Any]) -> None:
    """Wait for expected input."""
    transport = step.get("transport", "vga")
    text = _expand(session, _required_string(step, "text"))
    match = _match(step.get("match", "text"))
    timeout = step.get("timeout")
    if timeout is not None and not isinstance(timeout, (int, float)):
        raise ConfigError("wait timeout must be a number")
    if transport == "vga":
        session.vga_wait(text, match=match, timeout=timeout)
    elif transport == "serial":
        session.serial.wait(
            text,
            line=match is Match.LINE,
            regex=match is Match.REGEX,
            timeout=timeout,
        )
    else:
        raise ConfigError(f"Unknown wait transport: {transport}")


def _type(session: InstallSession, step: dict[str, Any]) -> None:
    """Type configured text through the VGA keyboard transport."""
    session.kb_type(_expand(session, _required_string(step, "text")))


def _press(session: InstallSession, step: dict[str, Any]) -> None:
    """Send configured literal key sequences."""
    keys = step.get("keys")
    if isinstance(keys, str):
        keys = [keys]
    if not isinstance(keys, list) or not all(isinstance(key, str) for key in keys):
        raise ConfigError("press action requires string keys")
    repeat = step.get("repeat", 1)
    if not isinstance(repeat, int) or isinstance(repeat, bool) or repeat < 1:
        raise ConfigError("press repeat must be a positive integer")
    for _ in range(repeat):
        session.kb_press(*keys)


def _prompt(session: InstallSession, step: dict[str, Any]) -> None:
    """Answer one or more configured serial prompts."""
    questions = step.get("questions", step.get("text"))
    if isinstance(questions, str):
        questions = [questions]
    if not isinstance(questions, list) or not all(
        isinstance(question, str) for question in questions
    ):
        raise ConfigError("prompt action requires text or questions")
    session.serial.prompt(
        *(_expand(session, question) for question in questions),
        answer=_expand(session, _string(step, "answer", "")),
        regex=_boolean(step, "regex", False),
    )


def _serial_shell_start(session: InstallSession, step: dict[str, Any]) -> None:
    """Start an interactive shell on the automation serial port."""
    session.serial_shell_start(
        screen_prompt=_string(step, "screen_prompt", "#"),
        serial_prompt=_string(step, "serial_prompt", "#"),
    )


def _serial_shell_send(session: InstallSession, step: dict[str, Any]) -> None:
    """Run one command in the active serial shell."""
    session.serial_shell_send(
        _expand(session, _required_string(step, "command")),
        wait=_boolean(step, "wait", True),
        prompt=_string(step, "prompt", "#"),
    )


def _serial_send(session: InstallSession, step: dict[str, Any]) -> None:
    """Send raw configured text over the automation serial port."""
    session.serial.send(_expand(session, _string(step, "text", "")))


def _serial_shell_exit(session: InstallSession, step: dict[str, Any]) -> None:
    """Exit the active serial shell and wait for VGA recovery."""
    session.serial_shell_exit(screen_prompt=_string(step, "screen_prompt", "#"))


def _console_echo(session: InstallSession, step: dict[str, Any]) -> None:
    """Write configured text to the guest's visible console."""
    session.serial_console_echo(_expand(session, _required_string(step, "text")))


def _partition(session: InstallSession, step: dict[str, Any]) -> None:
    """Partition the configured target disk with the shared fdisk driver."""
    values = session.config.install_values
    swap_mb = step.get("swap_mb", values.get("swap_mb", 64))
    if not isinstance(swap_mb, int) or isinstance(swap_mb, bool):
        raise ConfigError("partition swap_mb must be an integer")
    Fdisk(session).partition(
        _expand(session, _string(step, "device", str(values.get("target_disk", "/dev/hda")))),
        swap_mb,
    )


def _change_floppy(session: InstallSession, step: dict[str, Any]) -> None:
    """Insert the configured floppy image."""
    session.change_floppy(_expand(session, _required_string(step, "image")))


def _set_boot(session: InstallSession, step: dict[str, Any]) -> None:
    """Change QEMU's next boot device."""
    session.set_boot(_required_string(step, "device"))


def _run_postinst(session: InstallSession, step: dict[str, Any]) -> None:
    """Log into the installed system and launch staged post-installation."""
    password = step.get("password")
    if password is not None and not isinstance(password, str):
        raise ConfigError("run-postinst password must be a string")
    session.run_postinst(
        _expand(session, password) if password is not None else None,
        login=_expand(session, _string(step, "login", "login:")),
        shell=_expand(session, _string(step, "shell", "#")),
    )


def _expand(session: InstallSession, value: str) -> str:
    """Expand install-value references in declarative strings."""

    def replace(match: re.Match[str]) -> str:
        """Resolve one install-value interpolation match."""
        path = match.group(1).split(".")
        result = session.config.value(*path)
        if result is None:
            raise ConfigError(f"Unknown config interpolation: {match.group(1)}")
        return str(result)

    return re.sub(r"\$\{([a-zA-Z0-9_.]+)\}", replace, value)


def _match(value: object) -> Match:
    """Convert a declarative match name to a Match mode."""
    try:
        return Match(str(value))
    except ValueError as exc:
        raise ConfigError(f"Unknown match mode: {value}") from exc


def _required_string(table: dict[str, Any], key: str) -> str:
    """Read a required string field from an installer step."""
    value = table.get(key)
    if not isinstance(value, str):
        raise ConfigError(f"Expected string setting: {key}")
    return value


def _string(table: dict[str, Any], key: str, default: str) -> str:
    """Read an optional string field from an installer step."""
    value = table.get(key, default)
    if not isinstance(value, str):
        raise ConfigError(f"Expected string setting: {key}")
    return value


def _boolean(table: dict[str, Any], key: str, default: bool) -> bool:
    """Read an optional Boolean field from declarative configuration."""
    value = table.get(key, default)
    if not isinstance(value, bool):
        raise ConfigError(f"Expected boolean setting: {key}")
    return value


STEP_HANDLERS: dict[str, StepHandler] = {
    "change-floppy": _change_floppy,
    "console-echo": _console_echo,
    "partition": _partition,
    "press": _press,
    "prompt": _prompt,
    "run-postinst": _run_postinst,
    "serial-send": _serial_send,
    "serial-shell-exit": _serial_shell_exit,
    "serial-shell-send": _serial_shell_send,
    "serial-shell-start": _serial_shell_start,
    "set-boot": _set_boot,
    "type": _type,
    "wait": _wait,
}
STEP_ACTIONS = frozenset(STEP_HANDLERS)


DRIVERS: dict[str, Driver] = {
    "debian-dinstall": run_dinstall,
    "prompt-sequence": _prompt_sequence,
    "redhat-c": run_c_installer,
    "redhat-perl": run_perl_installer,
    "redhat-unattended": run_unattended,
    "slackware-pkgtool": run_pkgtool,
    "slackware-sysinstall": run_sysinstall,
}
DRIVER_OPTIONS = {
    "debian-dinstall": DinstallOptions,
    "redhat-c": CInstallerOptions,
    "redhat-perl": PerlInstallerOptions,
    "slackware-pkgtool": PkgtoolOptions,
    "slackware-sysinstall": SysinstallOptions,
}
DRIVER_CONTROL_FIELDS = {
    "debian-dinstall": {"prompt", "command", "root_prompt", "root_image"},
    "redhat-perl": {"flow"},
    "slackware-pkgtool": {
        "boot_prompt",
        "root_prompt",
        "root_image",
        "keyboard_prompt",
        "continuation_prompt",
    },
}
