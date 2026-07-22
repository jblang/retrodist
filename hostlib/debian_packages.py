"""Parse Debian package indexes and generate dependency-ordered guest installers."""

from __future__ import annotations

from dataclasses import dataclass
import gzip
from pathlib import Path, PurePosixPath
import re

from .errors import ConfigError
from .schemas import DebianPackagesConfig


@dataclass(frozen=True, slots=True)
class DebianPackage:
    """Represent the package fields used for selection and dependency resolution."""

    fields: dict[str, str]

    @property
    def name(self) -> str:
        """Return the package name."""
        return self.fields["package"]

    @property
    def key(self) -> str:
        """Return a case-insensitive package key."""
        return self.name.lower()


def load_packages(path: Path) -> list[DebianPackage]:
    """Parse a plain or gzip-compressed Debian control-file package index."""
    with path.open("rb") as stream:
        compressed = stream.read(2) == b"\x1f\x8b"
    opener = gzip.open if compressed else open
    with opener(path, "rt", encoding="utf-8", errors="surrogateescape") as stream:
        text = stream.read()
    records: list[dict[str, str]] = []
    current: dict[str, str] = {}
    field: str | None = None
    for line in [*text.splitlines(), ""]:
        if not line:
            if current:
                if "package" not in current:
                    raise ConfigError("Debian Packages paragraph has no Package field")
                records.append(current)
                current = {}
                field = None
            continue
        if line[0].isspace():
            if field is None:
                raise ConfigError("Debian Packages continuation has no field")
            current[field] += "\n" + line[1:]
            continue
        if ":" not in line:
            raise ConfigError(f"Invalid Debian Packages field: {line}")
        name, value = line.split(":", 1)
        field = name.lower()
        current[field] = value.lstrip()
    return [DebianPackage(record) for record in records]


def _dependency_groups(value: str) -> list[list[str]]:
    """Parse dependency names while ignoring versions and architecture qualifiers."""
    groups: list[list[str]] = []
    for group in value.split(","):
        alternatives = []
        for item in group.split("|"):
            name = re.split(r"\s*[<(\[]", item.strip(), maxsplit=1)[0].strip().lower()
            if name:
                alternatives.append(name)
        if alternatives:
            groups.append(alternatives)
    return groups


def resolve_packages(
    packages: list[DebianPackage], selection: DebianPackagesConfig
) -> list[DebianPackage]:
    """Select packages and recursively place dependencies before their users."""
    by_name = {package.key: package for package in packages}
    skipped = {name.lower() for name in selection.skip}
    unknown_skips = skipped.difference(by_name)
    if unknown_skips:
        raise ConfigError(f"Unknown Debian package skipped: {sorted(unknown_skips)[0]}")
    providers: dict[str, list[DebianPackage]] = {}
    for package in packages:
        for name in _dependency_groups(package.fields.get("provides", "")):
            for provided in name:
                providers.setdefault(provided, []).append(package)
    section_priorities = {
        section.lower(): {priority.lower() for priority in priorities}
        for section, priorities in selection.sections.items()
    }
    global_priorities = {item.lower() for item in selection.priorities}
    initial = set()
    for package in packages:
        section = package.fields.get("section", "").lower()
        priorities = section_priorities.get(section, global_priorities)
        if package.fields.get("priority", "").lower() in priorities:
            initial.add(package.key)
    for name in selection.add:
        key = name.lower()
        if key not in by_name:
            raise ConfigError(f"Unknown Debian package added: {name}")
        initial.add(key)
    initial.difference_update(skipped)
    ordered: list[DebianPackage] = []
    complete: set[str] = set()
    visiting: set[str] = set()

    def visit(package: DebianPackage) -> None:
        """Depth-first resolve one package, tolerating dependency cycles."""
        if package.key in complete or package.key in visiting:
            return
        visiting.add(package.key)
        dependencies = ",".join(
            filter(None, (package.fields.get("pre-depends"), package.fields.get("depends")))
        )
        for alternatives in _dependency_groups(dependencies):
            candidate = next(
                (by_name[name] for name in alternatives if name in by_name and name not in skipped),
                None,
            )
            if candidate is None:
                candidate = next(
                    (
                        provider
                        for name in alternatives
                        for provider in providers.get(name, [])
                        if provider.key not in skipped
                    ),
                    None,
                )
            if candidate is None:
                raise ConfigError(
                    f"Unresolved dependency for Debian package {package.name}: "
                    + " | ".join(alternatives)
                )
            visit(candidate)
        visiting.remove(package.key)
        complete.add(package.key)
        ordered.append(package)

    for key in sorted(initial):
        visit(by_name[key])
    return ordered


def render_installer(
    packages: list[DebianPackage], selection: DebianPackagesConfig
) -> str:
    """Render a portable shell script containing dependency-ordered dpkg commands."""
    lines = [
        "#!/bin/sh",
        "# Generated from Packages and config.toml; do not edit.",
    ]
    if selection.mount is not None:
        mount = selection.mount
        options = f" -o {_shell_word(mount.options)}" if mount.options else ""
        lines += [
            f"mkdir -p {_shell_word(mount.point)} || exit 1",
            f"mount -t {_shell_word(mount.filesystem)}{options} "
            f"{_shell_word(mount.device)} {_shell_word(mount.point)} || exit 1",
        ]
    root = selection.root.rstrip("/")
    for package in packages:
        filename = package.fields.get("filename")
        section = package.fields.get("section")
        if not filename or not section:
            raise ConfigError(f"Debian package {package.name} has no Filename or Section field")
        path = f"{root}/{section}/{PurePosixPath(filename).name}"
        lines.append(f"dpkg --install {_shell_word(path)} || exit 1")
    return "\n".join(lines) + "\n"


def _shell_word(value: str) -> str:
    """Single-quote one shell word without requiring modern shell features."""
    return "'" + value.replace("'", "'\\''") + "'"
