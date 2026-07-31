"""Python host runtime for downloading, staging, and installing retro distros.

The ``retro`` workflow resolves one ``RetroConfig`` and passes it through
``Downloader``, ``MediaStager``, and ``QemuRuntime``. Most host work is
synchronous. A live VM introduces one event loop for the QEMU process, QMP,
serial input, and VGA polling; installer drivers use ``InstallSession`` as a
linear synchronous facade from a worker thread.

Configuration is declarative and grouped by subsystem. Shared family drivers
and focused one-off drivers live under ``hostlib.installers`` while
release-specific values remain in TOML.
"""
