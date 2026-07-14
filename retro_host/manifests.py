from __future__ import annotations

import importlib.util
from pathlib import Path
from types import ModuleType

from .errors import ConfigError


def load(path: Path) -> ModuleType:
    name = f"retro_manifest_{abs(hash(path))}"
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise ConfigError(f"Could not load manifest {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

