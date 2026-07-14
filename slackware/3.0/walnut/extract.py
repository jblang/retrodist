from retro_host.media import Extraction


def normalize_boot_image(stager):
    image = stager.directory / "idecd"
    with image.open("r+b") as stream:
        stream.truncate(1440 * 1024)


extraction = Extraction(
    source="disc1.iso",
    boot_image="bootdsks.144/idecd",
    root_image="rootdsks/color.gz",
    after=normalize_boot_image,
)
