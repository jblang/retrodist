"""Python host runtime for downloading, staging, and installing retro distros.

The ``retro`` workflow resolves one ``RetroConfig`` and passes it through
``Downloader``, ``MediaStager``, and ``QemuRuntime``. Most host work is
synchronous. A live VM introduces one event loop for the QEMU process, QMP,
serial input, and VGA polling; installer drivers use ``InstallSession`` as a
linear synchronous facade from a worker thread.

Configuration is declarative and grouped by subsystem. Shared installer-family
drivers live under ``hostlib.installers`` while release-specific values and
bounded prompt sequences remain in TOML.
"""

from .context import Context

__all__ = ["Context"]
