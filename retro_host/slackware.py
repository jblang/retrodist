from __future__ import annotations

from collections import defaultdict
import logging
from pathlib import Path
import re
import shutil

from .context import Context
from .media import Iso

log = logging.getLogger(__name__)


def _package_name(filename: str) -> str:
    stem = re.sub(r"\.(?:tgz|tar)$", "", filename, flags=re.IGNORECASE)
    parts = stem.split("-")
    return "-".join(parts[:-3]) if len(parts) > 3 else stem


def _rules(context: Context) -> tuple[dict[tuple[str, str], str], dict[str, str]]:
    files: dict[str, Path] = {}
    for directory in (context.config.parent, context.config):
        for path in directory.glob("*.tag"):
            files[path.name] = path
    selected = [path for name, path in files.items() if Path(name).stem == "full"]
    exact: dict[tuple[str, str], str] = {}
    wildcard: dict[str, str] = {}
    for path in selected:
        for raw in path.read_text(errors="replace").splitlines():
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            fields = line.split()
            if len(fields) < 3 or fields[2] not in {"ADD", "REC", "OPT", "SKP"}:
                continue
            series, package, state = fields[:3]
            if package == "*":
                wildcard[series] = state
            else:
                exact[series, package] = state
    return exact, wildcard


def prepare_tagfiles(context: Context, qemu_dir: Path) -> None:
    if not context.name.startswith("slackware/"):
        return
    fat = qemu_dir / "fat"
    universe: list[tuple[Path, str, str]] = []
    package_root = next(
        (
            root
            for root in (fat / "packages", fat)
            if root.is_dir()
            and any(path.suffix.lower() in {".tgz", ".tar"} for path in root.glob("*/*"))
        ),
        None,
    )
    if package_root:
        for series_dir in package_root.iterdir():
            if not series_dir.is_dir():
                continue
            series = re.sub(r"\d+$", "", series_dir.name)
            first = package_root / f"{series}1/tagfile"
            for disk in package_root.glob(f"{series}[0-9]*"):
                for package in disk.iterdir():
                    if package.suffix.lower() in {".tgz", ".tar"}:
                        universe.append((first, series, _package_name(package.name)))
    else:
        iso_path = qemu_dir / "install.iso"
        if not iso_path.exists():
            iso_path = context.download_dir / "disc1.iso"
        if not iso_path.exists():
            return
        image = Iso(iso_path.resolve())
        try:
            for key, (_, directory) in image.paths.items():
                parts = Path(key).parts
                if directory or len(parts) < 3 or parts[1] not in {"slakware", "slackware"}:
                    continue
                if Path(parts[-1]).suffix.lower() not in {".tgz", ".tar"}:
                    continue
                disk = parts[-2]
                series = re.sub(r"\d+$", "", disk)
                universe.append(
                    (
                        fat / "tagfiles" / disk / "tagfile",
                        series,
                        _package_name(parts[-1]),
                    )
                )
        finally:
            image.close()
        shutil.rmtree(fat / "tagfiles", ignore_errors=True)
    if not universe:
        log.warning("No Slackware packages found for tagfile preparation")
        return
    exact, wildcard = _rules(context)
    outputs: dict[Path, list[str]] = defaultdict(list)
    included: set[str] = set()
    for target, series, package in sorted(set(universe), key=lambda row: tuple(map(str, row))):
        state = exact.get((series, package), wildcard.get(series, "SKP"))
        outputs[target].append(f"{package}:     {state}\n")
        if state != "SKP":
            included.add(series)
    for target, lines in outputs.items():
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("".join(lines))
    (fat / "disksets.txt").write_text(" ".join(sorted(included)) + "\n")


def generate_default_tag(context: Context, qemu_dir: Path) -> None:
    tagroot = context.tagfile_dir
    shutil.rmtree(tagroot, ignore_errors=True)
    tagroot.mkdir(parents=True)
    source = next(
        (
            path
            for path in (qemu_dir / "fat/packages", qemu_dir / "fat/install")
            if path.is_dir() and any(path.glob("*/tagfile*"))
        ),
        None,
    )
    if source:
        for path in source.glob("*/*"):
            if path.is_file() and (
                path.name in {"tagfile", "tagfile.org"}
                or path.name.startswith("disk")
                or path.suffix == ".txt"
            ):
                disk = path.parent.name
                first = re.sub(r"\d+$", "1", disk)
                target = tagroot / first / ("tagfile" if path.name == "tagfile.org" else path.name)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, target)
    else:
        iso_path = qemu_dir / "install.iso"
        if iso_path.exists():
            image = Iso(iso_path.resolve())
            try:
                for key, (actual, directory) in image.paths.items():
                    parts = Path(key).parts
                    if directory or len(parts) < 4 or parts[1] not in {"slakware", "slackware"}:
                        continue
                    name = parts[-1]
                    if (
                        name not in {"tagfile", "tagfile.org"}
                        and not name.startswith("disk")
                        and not name.endswith(".txt")
                    ):
                        continue
                    first = re.sub(r"\d+$", "1", parts[-2])
                    target = tagroot / first / ("tagfile" if name == "tagfile.org" else name)
                    image.extract_file(actual, target)
            finally:
                image.close()
    if not any(tagroot.glob("*/tagfile")):
        log.warning("No staged Slackware tagfiles found")
        return
    rows: list[str] = []
    for tagfile in sorted(tagroot.glob("*1/tagfile")):
        series = re.sub(r"\d+$", "", tagfile.parent.name)
        descriptions: dict[str, str] = {}
        for path in tagfile.parent.iterdir():
            if path == tagfile:
                continue
            for line in path.read_text(errors="replace").splitlines():
                if ":" in line and not line.startswith("CONTENTS:"):
                    name, description = line.split(":", 1)
                    if name.strip() and description.strip():
                        descriptions.setdefault(name.strip(), description.strip())
        packages: dict[str, str] = {}
        for line in tagfile.read_text(errors="replace").splitlines():
            match = re.match(r"([^:\s]+):\s*(ADD|REC|OPT|SKP)(?:\s|$)", line)
            if match:
                packages[match.group(1)] = match.group(2)
        if rows:
            rows.append("")
        rows.append(f"{series:<4} {'*':<12} SKP")
        for package in sorted(packages):
            row = f"{series:<4} {package:<12} {packages[package]:<4}"
            if package in descriptions:
                row += f"  # {descriptions[package]}"
            rows.append(row.rstrip())
    (context.config / "default.tag").write_text("\n".join(rows) + "\n")
