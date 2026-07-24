"""Shared strict-model base and user-facing validation error translation."""

from __future__ import annotations

from typing import TypeVar

from pydantic import BaseModel, ConfigDict, ValidationError

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
    if path == "install" and error_type == "union_tag_not_found":
        return "config.toml must set install.driver"
    if path == "install" and error_type == "union_tag_invalid":
        return f"Unknown install driver: {error['input'].get('driver')}"
    if path == "download" and error_type == "missing" and location[-1] == "url":
        return f"Missing URL for download.files entry {int(location[-2]) + 1}"
    if path == "install" and error_type == "too_short":
        return "prompt-sequence driver requires install.steps"
    if path == "install" and location == ("driver",):
        return "config.toml must set install.driver"
    if path == "install" and "keys" in location:
        step = location.index("steps")
        return f"install.steps entry {int(location[step + 1]) + 1} keys must be strings"
    if path == "postinst" and error_type == "literal_error":
        return f"Unknown post-install stage(s): {error['input']}"
    if (path == "install.redhat" and location == ("flow",)) or (
        path == "install" and location[-2:] == ("redhat", "flow")
    ):
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
