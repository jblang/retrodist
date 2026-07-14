from retro_host.install import Match


def install(session):
    session.vga_wait("boot:", match=Match.LINE)
    session.kb_type("linux ks=floppy", enter=True)
    session.vga_wait("Congratulations, installation is complete.")
    session.set_boot("c")
    session.kb_press("ret")
    session.run_postinst(
        "password", login="localhost login:", shell="[root@localhost /root]#"
    )
