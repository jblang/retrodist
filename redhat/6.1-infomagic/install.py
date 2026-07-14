from retro_host.install import Match


def install(session):
    session.vga_wait("boot:", match=Match.LINE)
    session.kb_type("text", enter=True)
    session.vga_wait("Congratulations, installation is complete.")
    session.set_boot("c")
    session.kb_press("ret")
