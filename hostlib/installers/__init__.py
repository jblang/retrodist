"""Validate and dispatch declarative installer configuration.

Named family drivers handle installers with reusable branching behavior. The
``prompt-sequence`` driver is intentionally bounded to a registry of simple,
validated actions for exceptional linear flows. Both paths operate through the
synchronous ``InstallSession`` API.
"""

from __future__ import annotations

import re
from typing import Any, Callable

from ..config import RetroConfig
from ..errors import ConfigError
from ..fdisk import Fdisk
from ..schemas import (
    ChangeFloppyStep,
    ConsoleEchoStep,
    PartitionStep,
    PressStep,
    PromptStep,
    RunPostinstStep,
    SerialSendStep,
    SerialShellExitStep,
    SerialShellSendStep,
    SerialShellStartStep,
    SetBootStep,
    TypeStep,
    WaitStep,
)
from ..session import InstallSession, Match
from .debian import run_dinstall
from .redhat_c import run_c_installer, run_unattended
from .redhat_perl import run_perl_installer
from .slackware import run_pkgtool
from .slackware_sysinstall import run_sysinstall

Driver = Callable[[InstallSession], None]
StepHandler = Callable[[InstallSession, Any], None]


def run_configured_install(session: InstallSession) -> None:
    """Validate and run the installer driver selected by configuration.

    Driver code receives the shared session and reads typed configuration
    models from it.
    """
    entrypoint = validate_install_config(session.config)
    entrypoint(session)


def validate_install_config(config: RetroConfig) -> Driver:
    """Validate the selected installer driver and return its entry point.

    Validation covers driver-specific option leaves, control tables, and every
    prompt-sequence action before QEMU starts.

    Raises:
        ConfigError: If the driver configuration or declarative steps are invalid.
    """
    driver = config.install.driver
    try:
        entrypoint = DRIVERS[driver]
    except KeyError as exc:
        raise ConfigError(f"Unknown install driver: {driver}") from exc
    return entrypoint


def _prompt_sequence(session: InstallSession) -> None:
    """Execute the configured linear prompt sequence in declaration order.

    Values such as ``${install.network.hostname}`` are expanded immediately
    before each action, allowing steps to reuse logically grouped settings.
    """
    for step in session.config.prompt_sequence.steps:
        STEP_HANDLERS[step.action](session, step)


def _wait(session: InstallSession, step: WaitStep) -> None:
    """Wait for expected input."""
    text = _expand(session, step.text)
    match = Match(step.match)
    if step.transport == "vga":
        session.vga_wait(text, match=match, timeout=step.timeout)
    else:
        session.serial.wait(
            text,
            line=match is Match.LINE,
            regex=match is Match.REGEX,
            timeout=step.timeout,
        )


def _type(session: InstallSession, step: TypeStep) -> None:
    """Type configured text through the VGA keyboard transport."""
    session.kb_type(_expand(session, step.text))


def _press(session: InstallSession, step: PressStep) -> None:
    """Send configured literal key sequences."""
    keys = step.keys
    if isinstance(keys, str):
        keys = [keys]
    for _ in range(step.repeat):
        session.kb_press(*keys)


def _prompt(session: InstallSession, step: PromptStep) -> None:
    """Answer one or more configured VGA or serial prompts."""
    questions = step.questions if step.questions is not None else step.text
    assert questions is not None
    if isinstance(questions, str):
        questions = [questions]
    expanded = [_expand(session, question) for question in questions]
    answer = _expand(session, step.answer)
    if step.transport == "vga":
        match = Match.REGEX if step.regex else Match.TEXT
        session.vga_wait(*expanded, match=match)
        session.kb_type(f"{answer}\n")
    else:
        session.serial.prompt(*expanded, answer=answer, regex=step.regex)


def _serial_shell_start(session: InstallSession, step: SerialShellStartStep) -> None:
    """Start an interactive shell on the automation serial port."""
    session.serial_shell_start(
        screen_prompt=step.screen_prompt,
        serial_prompt=step.serial_prompt,
    )


def _serial_shell_send(session: InstallSession, step: SerialShellSendStep) -> None:
    """Run configured commands in order in the active serial shell."""
    commands = [step.command] if isinstance(step.command, str) else step.command
    for command in commands:
        session.serial_shell_send(
            _expand(session, command),
            wait=step.wait,
            prompt=step.prompt,
        )


def _serial_send(session: InstallSession, step: SerialSendStep) -> None:
    """Send raw configured text over the automation serial port."""
    session.serial.send(_expand(session, step.text))


def _serial_shell_exit(session: InstallSession, step: SerialShellExitStep) -> None:
    """Exit the active serial shell and wait for VGA recovery."""
    session.serial_shell_exit(screen_prompt=step.screen_prompt)


def _console_echo(session: InstallSession, step: ConsoleEchoStep) -> None:
    """Write configured text to the guest's visible console."""
    session.serial_console_echo(_expand(session, step.text))


def _partition(session: InstallSession, step: PartitionStep) -> None:
    """Partition the configured target disk with the shared fdisk driver."""
    common = session.config.install_common
    swap_mb = step.swap_mb if step.swap_mb is not None else common.swap_mb
    Fdisk(session).partition_swap_root(
        _expand(session, step.device or common.target_disk),
        swap_mb,
    )


def _change_floppy(session: InstallSession, step: ChangeFloppyStep) -> None:
    """Insert the configured floppy image."""
    session.change_floppy(_expand(session, step.image))


def _set_boot(session: InstallSession, step: SetBootStep) -> None:
    """Change QEMU's next boot device."""
    session.set_boot(step.device)


def _run_postinst(session: InstallSession, step: RunPostinstStep) -> None:
    """Log into the installed system and launch staged post-installation."""
    session.run_postinst(
        _expand(session, step.password) if step.password is not None else None,
        login=_expand(session, step.login),
        shell=_expand(session, step.shell),
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
