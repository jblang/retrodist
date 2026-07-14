from retro_host.install.drivers.slackware import PkgtoolOptions, boot_pkgtool


def install(session):
    options = PkgtoolOptions(xwmconfig=True)
    options.postinst_prompt = f"root@{options.hostname}:~#"
    boot_pkgtool(session, keyboard_prompt=True, options=options)
