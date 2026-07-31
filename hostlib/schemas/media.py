"""Typed configuration for declarative media extraction."""

from __future__ import annotations

from pydantic import Field, model_validator

from .base import ConfigModel


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

    @property
    def staged_files(self) -> list[str]:
        """Return files copied to the root of the staging directory."""
        return [
            path
            for path in (
                self.boot_image,
                self.root_image,
                *self.extra_images,
                *self.files,
                self.package_index,
            )
            if path
        ]

    @property
    def package_paths(self) -> list[str]:
        """Return the normalized singular or plural package-tree selectors."""
        return self.package_sources or ([self.package_source] if self.package_source else [])
